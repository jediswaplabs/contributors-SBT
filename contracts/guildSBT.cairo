%lang starknet
// @title GuildSBT to mint contributor SBTs to community.
// @author Mesh Finance
// @license MIT

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_le,
    uint256_check,
    uint256_lt,
    uint256_sqrt,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_unsigned_div_rem,
)
from contracts.utils.math import (
    uint256_checked_add,
    uint256_checked_sub_lt,
    uint256_checked_sub_le,
    uint256_checked_mul,
    uint256_felt_checked_mul,
)
from starkware.cairo.common.bool import TRUE, FALSE

// # from openzeppelin.token.erc721.library import ERC721
// from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.access.ownable.library import Ownable

from cairopen.string.string import String
from cairopen.string.ASCII import StringCodec
from cairopen.string.utils import StringUtil

// #
// # Interfaces
// #
@contract_interface
namespace IMaster {
    func design_points(contributor: felt) -> (design_points: felt) {
    }
}

//
// Storage ERC 721
//

// @dev name of SBT collection
@storage_var
func _name() -> (name: felt) {
}

// @dev symbol of SBT collection
@storage_var
func _symbol() -> (symbol: felt) {
}

// @dev holder address of SBTs by id
@storage_var
func _owners(token_id: felt) -> (owner: felt) {
}

// @dev holder address of SBTs by id
@storage_var
func _wallet_of_owner(account: felt) -> (token_id: felt) {
}

// @dev SBT balance of an account
@storage_var
func _balances(account: felt) -> (balance: felt) {
}

// @dev total SBTs minted
@storage_var
func _total_supply() -> (res: felt) {
}

//
// Storage guild SBT
//

// @dev master contract for storing SBT metadata (contribuion points)
@storage_var
func _master() -> (res: felt) {
}

// @dev contribution tier limit
@storage_var
func _contribution_tier(tier: felt) -> (points: felt) {
}

// @dev number of contibution tiers (levels)
@storage_var
func _number_of_tiers() -> (res: felt) {
}

// @dev SBT type for owner
@storage_var
func _token_type(owner: felt) -> (res: felt) {
}

// @dev baseURI for SBT metadata
@storage_var
func _baseURI() -> (res: felt) {
}

//
// Events
//
@event
func Transfer(from_: felt, to: felt, tokenId: felt) {
}

@event
func MasterUpdated(old_master: felt, new_master: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, baseURI: felt, master: felt
) {
    _name.write('Design Guild SBT');
    _symbol.write('DESIGN');
    _master.write(master);
    Ownable.initializer(owner);
    // initilasing contribution tier
    _contribution_tier.write(1, 100);
    _contribution_tier.write(2, 250);
    _contribution_tier.write(3, 500);
    _contribution_tier.write(4, 750);
    _contribution_tier.write(5, 1000);

    _number_of_tiers.write(5);
    _baseURI.write(baseURI);
    return ();
}

//
// Getters
//

// @view
// func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     interfaceId: felt
// ) -> (success: felt) {
//     let (success) = ERC165.supports_interface(interfaceId);
//     return (success,);
// }

// @notice Get name of SBT collection
// @return name
@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = _name.read();
    return (name,);
}

// @notice Get symbol of SBT collection
// @return symbol
@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    let (symbol) = _symbol.read();
    return (symbol,);
}

// @notice Get balance of owner
// @return balance
@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) -> (
    balance: felt
) {
    with_attr error_message("GuildSBT: balance query for the zero address") {
        assert_not_zero(owner);
    }
    let (balance: felt) = _balances.read(owner);
    return (balance,);
}

// @notice Get owner of SBT by token id
// @return owner
@view
func ownerOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> (owner: felt) {
    with_attr error_message("GuildSBT: token_id is not a valid Uint256") {
        uint256_check(Uint256(token_id,0));
    }
    let (owner) = _owners.read(token_id);
    // @Reviewer returning zero address instead of error in case of non existent token
    // with_attr error_message("GuildSBT: owner query for nonexistent token") {
    //     assert_not_zero(owner);
    // }
    return (owner,);
}

// @notice Get SBT token id of owner
// @return token od
@view
func wallet_of_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt
) -> (token_id: felt) {

    let (balance) = _balances.read(owner);
    if (balance == 0) {
        return (-1,);
    }
    let (token_id) = _wallet_of_owner.read(owner);

    return (token_id,);
}

// @notice Get tokenURI of SBT by token id
// @return name
@view
func tokenURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenId: felt
) -> (tokenURI: felt) {
    alloc_locals;
    let (owner) = ownerOf(tokenId);
    let (master) = _master.read();
    let (points) = IMaster.design_points(contract_address=master, contributor=owner);
    let (type) = _token_type.read(owner);

    let (contribution_tier) = _get_contribution_tier(1, points);
    // let contribution_tier = 1;
    // local syscall_ptr: felt* = syscall_ptr;
    // local pedersen_ptr: HashBuiltin* = pedersen_ptr;
    let (tokenURI) = _tokenURI(contribution_tier, type);
    return (tokenURI,);
}

@view
func get_contribution_tier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) -> (res: felt) {
    let (master) = _master.read();
    let (points) = IMaster.design_points(contract_address=master, contributor=user);

    let (res) = _get_contribution_tier(1, points);

    return (res,);
}

@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner) = Ownable.owner();
    return (owner,);
}

@view
func master{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (master: felt) {
    let (master) = _master.read();
    return (master,);
}

@view
func contribution_tier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tier: felt
) -> (res: felt) {
    let (res) = _contribution_tier.read(tier);
    return (res,);
}

@view
func number_of_tiers{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let (res) = _number_of_tiers.read();
    return (res,);
}

@view
func baseURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (res) = _baseURI.read();
    return (res,);
}
// 
// External guildSBT
// 

@external
func update_baseURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    baseURI: felt
) {
    Ownable.assert_only_owner();
    _baseURI.write(baseURI);
    return ();
}

@external
func update_contribution_tier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contribution_tier_len: felt, contribution_tier: felt*
) {
    Ownable.assert_only_owner();

    _update_contribution_tier(contribution_tier_len, contribution_tier);
    _number_of_tiers.write(contribution_tier_len);

    return ();
}

@external
func update_master{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_master: felt
) {
    Ownable.assert_only_owner();
    let (old_master) = _master.read();
    _master.write(new_master);

    MasterUpdated.emit(old_master, new_master);
    return ();
}

@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newOwner: felt
) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func renounceOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.renounce_ownership();
    return ();
}

@external
func safeMint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(type: felt) {
    alloc_locals;
    let (caller) = get_caller_address();
    let (caller_balance) = _balances.read(caller);

    with_attr error_message("guildSBT::safeMint::Already minted") {
        assert caller_balance = 0;
    }

    _token_type.write(caller, type);
    let (master) = _master.read();
    let (points) = IMaster.design_points(contract_address=master, contributor=caller);

    let (contribution_tier) = _get_contribution_tier(1, points);
    // let contribution_tier = 1;
    
    with_attr error_message("guildSBT::safeMint::Not enough points") {
        assert_not_zero(contribution_tier);
    }
    // local syscall_ptr: felt* = syscall_ptr;
    // local pedersen_ptr: HashBuiltin* = pedersen_ptr;
    _mint(caller);
    return ();
}
@external
func migrate_sbt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(old_owner: felt, new_owner: felt) {
    alloc_locals;

    let (caller) = get_caller_address();
    let (master) = _master.read();
    with_attr error_message("guildSBT: caller not Master") {
        assert caller = master;
    }

    let (old_owner_balance) = _balances.read(old_owner);
    // return if old_owner doesn't hold a SBT
    if (old_owner_balance == 0){
        return ();
    }
    with_attr error_message("guildSBT: cannot migrate to the zero address") {
        assert_not_zero(new_owner);
    }

    let (new_owner_balance) = _balances.read(new_owner);
    with_attr error_message("guildSBT: new owner already hold a SBT") {
        assert new_owner_balance = 0;
    }

    let (token_id) = _wallet_of_owner.read(old_owner);
    let (type) = _token_type.read(old_owner);

    // let (new_owner_balance_updated: Uint256) = uint256_checked_add(new_owner_balance, Uint256(1, 0));
    // _balances.write(new_owner, new_owner_balance);
    _balances.write(new_owner, new_owner_balance + 1);
    _balances.write(old_owner, old_owner_balance - 1);

    _owners.write(token_id, new_owner);
    _wallet_of_owner.write(new_owner, token_id);
    Transfer.emit(old_owner, new_owner, token_id);
    
    return ();
}

//
// Internal
//


func _update_contribution_tier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contribution_tier_len: felt, contribution_tier: felt*
) {
    alloc_locals;

    if (contribution_tier_len == 0) {
        return ();
    }

    _contribution_tier.write(contribution_tier_len, [contribution_tier]);

    return _update_contribution_tier(
        contribution_tier_len=contribution_tier_len - 1, contribution_tier=&contribution_tier[1]
    );
}

func _get_contribution_tier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt, points: felt
) -> (tier: felt) {
    alloc_locals;

    let (number_of_tiers) = _number_of_tiers.read();
    let (is_index_greater_than_number_of_tiers) = uint256_lt(
        Uint256(number_of_tiers, 0), Uint256(index, 0)
    );
    if (is_index_greater_than_number_of_tiers == 1) {
        // return (index - 1)
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        return (index - 1,);
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    let (tier_lowercap) = _contribution_tier.read(index);
    let (is_points_less_than_tier_lowecap) = uint256_lt(
        Uint256(points, 0), Uint256(tier_lowercap, 0)
    );
    if (is_points_less_than_tier_lowecap == 1) {
        // return (index - 1)
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        return (index - 1,);
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    // local syscall_ptr: felt* = syscall_ptr;
    // local pedersen_ptr: HashBuiltin* = pedersen_ptr;

    return _get_contribution_tier(index=index + 1, points=points);
}

func _tokenURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contribution_tier: felt, type: felt
) -> (tokenURI: felt) {
    alloc_locals;

    // let (contribution_tier_multiply_by_10: Uint256) = uint256_checked_mul(
    //     Uint256(contribution_tier, 0), Uint256(10, 0)
    // );
    // let (sbt_id: Uint256) = uint256_checked_add(contribution_tier_multiply_by_10, Uint256(type, 0));
    let sbt_id: felt = ((contribution_tier + 48) * 2**8) + type + 48;


    let (baseURI) = _baseURI.read();

    // let (baseURI_multiply_by_100: Uint256) = uint256_checked_mul(
    //     Uint256(baseURI, 0), Uint256(100, 0)
    // );

    // let (baseURI_str: String) = StringCodec.felt_to_string(baseURI);
    // let (id_str: String) = StringCodec.felt_to_string(sbt_id.low);

    // let (tokenURI) = StringUtil.concat(baseURI_str, id_str);

    // TODO: return baseURI + sbt_id
    // let (tokenURI_uint256) = uint256_checked_add(
    //     baseURI_multiply_by_100, sbt_id
    // );
    // let tokenURI = tokenURI_uint256.low;
    let tokenURI = baseURI*2**16 + sbt_id;
    return (tokenURI,);
}

func _mint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(to: felt) {
    with_attr error_message("guildSBT: cannot mint to the zero address") {
        assert_not_zero(to);
    }

    let (total_supply) = _total_supply.read();
    let token_id = total_supply;

    let (balance) = _balances.read(to);
    // let (new_balance) = balance + 1;
    _balances.write(to, balance + 1);

    let (total_supply) = _total_supply.read();
    // let (new_total_supply) = total_supply + 1;
    _total_supply.write(total_supply + 1);

    _owners.write(token_id, to);
    _wallet_of_owner.write(to, token_id);
    Transfer.emit(0, to, token_id);

    return ();
}

