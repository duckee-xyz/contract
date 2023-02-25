import DuckeeArtNFT from "./DuckeeArtNFT.cdc"
import NonFungibleToken from "./utility/NonFungibleToken.cdc"
import MetadataViews from "./utility/MetadataViews.cdc"

/// DuckeePromptSBT is a Soulbound Non-Fungible Token which indicates an access rights
/// to the prompt (i.e. recipe, the reproducible input to the generative AI model) of Duckee Art.
///
/// Purchasable
pub contract DuckeePromptSBT: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var supplyPerArtNFT: {UInt64: UInt64}

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event PromptMinted(id: UInt64, artTokenID: UInt64, recipient: Address);

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub struct DuckeePromptSBTMintData {
        pub let id: UInt64
        pub let artTokenID: UInt64

        init(id: UInt64, artTokenID: UInt64) {
            self.id = id
            self.artTokenID = artTokenID
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let artTokenID: UInt64

        init(id: UInt64, artTokenID: UInt64) {
            self.id = id
            self.artTokenID = artTokenID
        }

        pub fun getViews(): [Type] {
            return [ Type<DuckeePromptSBTMintData>() ];
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<DuckeePromptSBTMintData>():
                return DuckeePromptSBTMintData(
                    id: self.id,
                    artTokenID: self.artTokenID,
                )
            }
            return nil
        }
    }

    pub resource interface DuckeePromptSBTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowDuckeePromptSBT(id: UInt64): &DuckeePromptSBT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow DuckeePromptSBT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: DuckeePromptSBTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            panic("soulbound; not transferable")
        }

        // deposit takes an NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @DuckeePromptSBT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowDuckeePromptSBT(id: UInt64): &DuckeePromptSBT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DuckeePromptSBT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let DuckeePromptSBTNFT = nft as! &DuckeePromptSBT.NFT
            return DuckeePromptSBTNFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun mintPromptSBT(
        artTokenOwner: &{DuckeeArtNFT.DuckeeArtNFTCollectionPublic},
        artTokenID: UInt64,
        promptRecipient: &{NonFungibleToken.Receiver},
    ) {
        pre {
            artTokenOwner.borrowDuckeeArtNFT(id: artTokenID) != nil: "only Art NFT owner can mint the prompt SBT"
        }
        // create a new Prompt SBT
        var newNFT <- create NFT(
            id: DuckeePromptSBT.totalSupply,
            artTokenID: artTokenID,
        )
        emit PromptMinted(id: newNFT.id, artTokenID: newNFT.artTokenID, recipient: promptRecipient.owner!.address)
        promptRecipient.deposit(token: <-newNFT)

        DuckeePromptSBT.totalSupply = DuckeePromptSBT.totalSupply + 1
        DuckeePromptSBT.supplyPerArtNFT[artTokenID] = (DuckeePromptSBT.supplyPerArtNFT[artTokenID] ?? 0) + 1
    }

    init() {
        self.totalSupply = 0
        self.supplyPerArtNFT = {}

        self.CollectionStoragePath = /storage/DuckeePromptSBTCollection
        self.CollectionPublicPath = /public/DuckeePromptSBTCollection

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        self.account.link<&DuckeePromptSBT.Collection{NonFungibleToken.CollectionPublic, DuckeePromptSBT.DuckeePromptSBTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
