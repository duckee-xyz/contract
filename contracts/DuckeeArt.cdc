import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

pub contract DuckeeArt: NonFungibleToken {
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub struct DuckeeArtMintData {
        pub let id: UInt64
        pub let type: String
        pub let url: String

        init(id: UInt64, type: String, url: String) {
            self.id = id
            self.type = type
            self.url = url
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let type: String
        pub let url: String

        init(id: UInt64, type: String, url: String) {
            self.id = id
            self.type = type
            self.url = url
        }

        pub fun getViews(): [Type] {
            return [ Type<DuckeeArtMintData>() ];
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<DuckeeArtMintData>():
                return DuckeeArtMintData(
                    id: self.id,
                    type: self.type,
                    url: self.url
                )
            }
            return nil
        }
    }

    pub resource interface DuckeeArtCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowDuckeeArt(id: UInt64): &DuckeeArt.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow DuckeeArt reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: DuckeeArtCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes an NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @DuckeeArt.NFT

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

        pub fun borrowDuckeeArt(id: UInt64): &DuckeeArt.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DuckeeArt.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let duckeeArtNFT = nft as! &DuckeeArt.NFT
            return duckeeArtNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, type: String, url: String) {
        // create a new NFT
        var newNFT <- create NFT(
            id: DuckeeArt.totalSupply,
            type: type,
            url: url,
        )
        recipient.deposit(token: <-newNFT)
        DuckeeArt.totalSupply = DuckeeArt.totalSupply + UInt64(1)
    }

    init() {
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/duckeeArtCollection
        self.CollectionPublicPath = /public/duckeeArtCollection
        self.MinterStoragePath = /storage/duckeeArtMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        self.account.link<&DuckeeArt.Collection{NonFungibleToken.CollectionPublic, DuckeeArt.DuckeeArtCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
