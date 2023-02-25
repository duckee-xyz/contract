import DuckeeArtNFT from "../../contracts/DuckeeArtNFT.cdc"
import PromptMarket from "../../contracts/PromptMarket.cdc"
import FlowToken from "../../contracts/utility/FlowToken.cdc"
import FungibleToken from "../../contracts/utility/FungibleToken.cdc"

/// Installs the Storefront ressource in an account.
transaction () {
    prepare(acct: AuthAccount) {
        if acct.borrow<&PromptMarket.Storefront>(from: PromptMarket.StorefrontStoragePath) != nil {
            // already created 
            return
        }

        let revenueReceiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(revenueReceiver.borrow() != nil, message: "missing or mis-typed receiver")

        let collectionCapability= acct.link<&DuckeeArtNFT.Collection>(/private/PromptMarketSaleCollection, target: DuckeeArtNFT.CollectionPublicPath) 
            ?? panic("unable to create private link to DuckeeArtNFT collection")

        let sales <- PromptMarket.createStorefront(
            ownerCollection: collectionCapability,
            revenueVault: revenueReceiver,
        )
        acct.save(<-sales, to: PromptMarket.StorefrontStoragePath)

        // Create a public capability to the Storefront so that others can call its methods
        acct.link<&PromptMarket.Storefront{PromptMarket.StorefrontPublic}>(PromptMarket.StorefrontPublicPath, target: PromptMarket.StorefrontStoragePath)
    }
}
