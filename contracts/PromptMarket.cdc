import DuckeeArtNFT from "./DuckeeArtNFT.cdc";
import DuckeePromptSBT from "./DuckeePromptSBT.cdc";
import FlowToken from "./utility/FlowToken.cdc"
import FungibleToken from "./utility/FungibleToken.cdc"
import NonFungibleToken from "./utility/NonFungibleToken.cdc"

pub contract PromptMarket {
    pub let StorefrontStoragePath: StoragePath
    pub let StorefrontPublicPath: PublicPath

    pub struct Listing {
        pub var tokenID: UInt64
        pub var priceInUSDC: UFix64
        pub var royaltyFee: UFix64

        init(tokenID: UInt64, priceInUSDC: UFix64, royaltyFee: UFix64) {
            self.tokenID = tokenID
            self.priceInUSDC = priceInUSDC
            self.royaltyFee = royaltyFee
        }
    }

    pub resource interface StorefrontPublic {
        pub fun purchase(tokenID: UInt64, recipient: Capability<&AnyResource{NonFungibleToken.Receiver}>, payment: @FlowToken.Vault)
        pub fun listingInfo(tokenID: UInt64): Listing?
        pub fun getListedTokenIDs(): [UInt64]
    }

    /// Storefront per an account.
    pub resource Storefront: StorefrontPublic {

        /// A capability for the owner's collection
        access(self) var ownerCollection: Capability<&DuckeeArtNFT.Collection>

        access(self) var listings: {UInt64: Listing}

        // The fungible token vault of the owner of this sale.
        // When someone buys a prompt / child token's prompt, revenue and royalty comes here 
        access(account) let revenueVault: Capability<&AnyResource{FungibleToken.Receiver}>

        init (ownerCollection: Capability<&DuckeeArtNFT.Collection>,
              revenueVault: Capability<&AnyResource{FungibleToken.Receiver}>) {

            pre {
                // Check that the owner's collection capability is correct
                ownerCollection.check(): "Owner's NFT Collection Capability is invalid!"

                // Check that the fungible token vault capability is correct
                revenueVault.check(): "Owner's Receiver Capability is invalid!"
            }
            self.ownerCollection = ownerCollection
            self.revenueVault = revenueVault
            self.listings = {}
        }

        pub fun list(tokenID: UInt64, priceInUSDC: UFix64, royaltyFee: UFix64) {
            pre {
                self.ownerCollection.borrow()!.borrowNFT(id: tokenID) != nil: "owner does not own the token"
                royaltyFee < UFix64(0.5): "royaltyFee range overflow: max is 0.5"
            }
            self.listings[tokenID] = Listing(
                tokenID: tokenID,
                priceInUSDC: priceInUSDC,
                royaltyFee: royaltyFee,
            )
        }

        pub fun listingInfo(tokenID: UInt64): Listing? {
            return self.listings[tokenID]
        }

        pub fun purchase(tokenID: UInt64, recipient: Capability<&AnyResource{NonFungibleToken.Receiver}>, payment: @FlowToken.Vault) {
            pre {
                self.listings[tokenID] != nil: "given token ID is not listed yet"
                payment.balance >= self.listings[tokenID]!.priceInUSDC: "insufficient USDC amount"
                recipient.check(): "invalid NFT capabilities for recipient"
            }

            // deposit the revenue to the owner
            // TODO: redirect royalty to the ancestor
            let vaultRef = self.revenueVault.borrow() ?? panic("could not borrow reference to owner token vault")
            vaultRef.deposit(from: <-payment)

            // mint prompt SBT from art NFT
            let receiverRef = recipient.borrow()!
            DuckeePromptSBT.mintPromptSBT(
                artTokenOwner: self.ownerCollection.borrow()!,
                artTokenID: tokenID, 
                promptRecipient: receiverRef,
            )
        }

        /// getListedTokenIDs returns an array of the IDs that are in the collection
        pub fun getListedTokenIDs(): [UInt64] {
            return self.listings.keys
        }

        pub fun editListing(tokenID: UInt64, newValue: Listing) {
            pre {
                self.listings.containsKey(tokenID): "given token ID is not listed yet"
            }
            self.listings[tokenID] = newValue
        }

        pub fun unlist(tokenID: UInt64) {
            self.listings.remove(key: tokenID) ?? panic("tokenID not listed")
        }
    }

    pub fun createStorefront(
        ownerCollection: Capability<&DuckeeArtNFT.Collection>,
        revenueVault: Capability<&AnyResource{FungibleToken.Receiver}>,
    ): @PromptMarket.Storefront {
        return <-create Storefront(
            ownerCollection: ownerCollection,
            revenueVault: revenueVault,
        )
    }

    init() {
        self.StorefrontStoragePath = /storage/PromptMarketStorefront
        self.StorefrontPublicPath = /public/PromptMarketStorefront
    }
}
