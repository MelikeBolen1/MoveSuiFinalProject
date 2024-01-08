module nft_marketplace::marketplace {
    use std::string::{Self, String};
    use std::collections::vector;
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object_table::{Self, ObjectTable};
    use sui::event;
    use sui::auth;

    // NFT structure
    struct NFT has key, store {
        id: UID,                // Unique identifier of the NFT
        owner: address,         // Address of the NFT owner
        title: String,          // NFT title
        description: String,    // NFT description
        artist: String,         // Artist's name
        digital_version: String,// Digital version of the artwork
        for_sale: bool,         // Flag indicating if the NFT is listed for sale
        price: u64,             // Price of the NFT
    }

    // User structure
    struct User has key, store {
        id: UID,                // Unique identifier of the user
        address: address,       // User's address
        verified: bool,         // User verification status
        portfolio: vector<UID>, // Identifiers of NFTs owned by the user
        comments: vector<Comment>, // Comments made by the user
    }

    // Comment structure
    struct Comment has key, store {
        id: UID,                // Unique identifier of the comment
        author: UID,            // Identifier of the comment author
        text: String,           // Comment text
        rating: u8,             // Comment rating
    }

    // NFT creation function
    public entry fun create_nft(
        title: vector<u8>,
        description: vector<u8>,
        artist: vector<u8>,
        digital_version: vector<u8>,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let payment_value = coin::value(&payment);
        assert!(payment_value >= MIN_NFT_COST, INSUFFICENT_FUNDS);
        transfer::public_transfer(payment, tx_context::sender(ctx));

        let id = object::new(ctx);

        let nft = NFT {
            id: id,
            owner: tx_context::sender(ctx),
            title: string::utf8(title),
            description: string::utf8(description),
            artist: string::utf8(artist),
            digital_version: string::utf8(digital_version),
            for_sale: false,
            price: 0,
        };

        object_table::add(&mut nft_table, object::uid_to_inner(&id), nft);
    }

    // List NFT for sale function
    public entry fun list_nft_for_sale(nft_id: UID, price: Coin<SUI>, ctx: &mut TxContext) {
        // User listing their NFT for sale
        let nft = object_table::borrow_mut(&mut nft_table, object::uid_to_inner(&nft_id));
        assert!(nft.owner == tx_context::sender(ctx), NOT_THE_OWNER);

        // Listing the NFT on the marketplace
        nft.for_sale = true;
        nft.price = coin::value(&price);

        event::emit(NFTListed {
            nft_id: nft_id,
            price: nft.price,
        });
    }

    // Buy NFT function
    public entry fun buy_nft(nft_id: UID, ctx: &mut TxContext) {
        let nft = object_table::borrow_mut(&mut nft_table, object::uid_to_inner(&nft_id));
        assert!(nft.for_sale, NOT_FOR_SALE);

        let buyer = tx_context::sender(ctx);
        let seller = nft.owner;

        // Payment process
        let price = nft.price;
        let payment = Coin::<SUI>::new(price);
        transfer::public_transfer(payment, seller);
        
        // Set the buyer as the new owner of the NFT
        nft.owner = buyer;
        nft.for_sale = false;

        event::emit(NFTSold {
            nft_id: nft_id,
            seller: seller,
            buyer: buyer,
            price: price,
        });
    }

    // User verification function
    public entry fun verify_user(user_id: UID, ctx: &mut TxContext) {
        // User verification process callable only by administrators
        auth::require_admin(ctx);

        let user = object_table::borrow_mut(&mut user_table, object::uid_to_inner(&user_id));
        user.verified = true;
    }

    // Get user's portfolio function
    public fun get_user_portfolio(user_id: UID): vector<UID> {
        let user = object_table::borrow(&user_table, object::uid_to_inner(&user_id));
        user.portfolio
    }

    // Get user's comments function
    public fun get_user_comments(user_id: UID): vector<Comment> {
        let user = object_table::borrow(&user_table, object::uid_to_inner(&user_id));
        user
