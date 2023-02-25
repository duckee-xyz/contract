import DuckeeArtNFT from "../../contracts/DuckeeArtNFT.cdc"
import PromptMarket from "../../contracts/PromptMarket.cdc"
import FlowToken from "../../contracts/utility/FlowToken.cdc"

transaction (tokenID: UInt64, priceInUSDC: UFix64, royaltyFee: UFix64) {
    let storefront: &PromptMarket.Storefront

    prepare(acct: AuthAccount) {
        self.storefront = acct.borrow<&PromptMarket.Storefront>(from: PromptMarket.StorefrontStoragePath) 
            ?? panic("please run prompt-market/setup-account first")
    }

    execute {
        self.storefront.list(tokenID: tokenID, priceInUSDC: priceInUSDC, royaltyFee: royaltyFee)
    }
}
