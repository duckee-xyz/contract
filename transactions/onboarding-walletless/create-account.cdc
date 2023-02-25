import DuckeeArtNFT from "../../contracts/DuckeeArtNFT.cdc"
import DuckeePromptSBT from "../../contracts/DuckeePromptSBT.cdc"
import DuckToken from "../../contracts/DuckToken.cdc"
import PromptMarket from "../../contracts/PromptMarket.cdc"
import ChildAccount from "../../contracts/utility/ChildAccount.cdc"
import MetadataViews from "../../contracts/utility/MetadataViews.cdc"
import FungibleToken from "../../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../../contracts/utility/NonFungibleToken.cdc"

transaction (       
    pubKey: String,
    fundingAmt: UFix64,
    childAccountName: String,
    childAccountDescription: String,
    clientIconURL: String,
    clientExternalURL: String,
) {
    prepare(signer: AuthAccount) {
        // 1. Create a new child account
        // Get a reference to the signer's ChildAccountCreator
        let creator = signer.borrow<&ChildAccount.ChildAccountCreator>(from: ChildAccount.ChildAccountCreatorStoragePath) 
            ?? panic("No ChildAccountCreator in signer's account; please run setup-child-account-creator.cdc first")

        // Construct the ChildAccountInfo metadata struct
        let info = ChildAccount.ChildAccountInfo(
                name: childAccountName,
                description: childAccountDescription,
                clientIconURL: MetadataViews.HTTPFile(url: clientIconURL),
                clienExternalURL: MetadataViews.ExternalURL(clientExternalURL),
                originatingPublicKey: pubKey
            )

        // Create the account
        let newAccount = creator.createChildAccount(
            signer: signer,
            initialFundingAmount: fundingAmt,
            childAccountInfo: info
        )

        // 2. Set up DuckeeArtNFT.Collection
        newAccount.save(<-DuckeeArtNFT.createEmptyCollection(), to: DuckeeArtNFT.CollectionStoragePath)

        // create a public capability for the collection
        newAccount.link<
            &DuckeeArtNFT.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, DuckeeArtNFT.DuckeeArtNFTCollectionPublic, MetadataViews.ResolverCollection}
        >(
            DuckeeArtNFT.CollectionPublicPath,
            target: DuckeeArtNFT.CollectionStoragePath
        )

        // Link the Provider Capability in private storage
        newAccount.link<
            &DuckeeArtNFT.Collection{NonFungibleToken.Provider}
        >(
            DuckeeArtNFT.ProviderPrivatePath,
            target: DuckeeArtNFT.CollectionStoragePath
        )

        // 3. Set up DuckToken
        newAccount.save(<-DuckToken.createEmptyVault(), to: DuckToken.VaultStoragePath)  

        // Create a public capability to the Vault that only exposes the deposit function
        // & balance field through the Receiver & Balance interface
        newAccount.link<&DuckToken.Vault{FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver}>(
            DuckToken.ReceiverPublicPath,
            target: DuckToken.VaultStoragePath
        )
        // Create a private capability to the Vault that only exposes the withdraw function
        // through the Provider interface
        newAccount.link<&DuckToken.Vault{FungibleToken.Provider}>(
            DuckToken.ProviderPrivatePath,
            target: DuckToken.VaultStoragePath
        )

        // 4. Set up DuckeePromptSBT
        newAccount.save(<-DuckeePromptSBT.createEmptyCollection(), to: DuckeePromptSBT.CollectionStoragePath)

        // create a public capability for the collection
        newAccount.link<
            &DuckeePromptSBT.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, DuckeePromptSBT.DuckeePromptSBTCollectionPublic, MetadataViews.ResolverCollection}
        >(
            DuckeePromptSBT.CollectionPublicPath,
            target: DuckeePromptSBT.CollectionStoragePath
        )

        // 5. Install PromptMarket Storefront
        let revenueReceiver = newAccount.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(revenueReceiver.borrow() != nil, message: "missing or mis-typed receiver")

        let collectionCapability= newAccount.link<&DuckeeArtNFT.Collection>(/private/PromptMarketSaleCollection, target: DuckeeArtNFT.CollectionPublicPath) 
            ?? panic("unable to create private link to DuckeeArtNFT collection")

        let sales <- PromptMarket.createStorefront(
            ownerCollection: collectionCapability,
            revenueVault: revenueReceiver,
        )
        newAccount.save(<-sales, to: PromptMarket.StorefrontStoragePath)

        // Create a public capability to the Storefront so that others can call its methods
        newAccount.link<&PromptMarket.Storefront{PromptMarket.StorefrontPublic}>(PromptMarket.StorefrontPublicPath, target: PromptMarket.StorefrontStoragePath)
    }
}
