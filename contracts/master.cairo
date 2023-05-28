%lang starknet
// @title Master for storing contributions point for guild SBT
// @author Mesh Finance
// @license MIT

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
)
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_chain import hash_chain

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_sqrt,
    uint256_unsigned_div_rem,
)
from contracts.utils.math import (
    uint256_checked_add,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_felt_checked_mul,
    uint256_checked_sub_le,
)

// from contracts.utils.crypto.sha256d.sha256d import (
//     sha256d_felt_sized,
//     copy_hash,
//     HASH_SIZE,
//     HASH_FELT_SIZE,
// )

@contract_interface
namespace IGuildSBT {
    func migrate_sbt(old_owner: felt, new_owner: felt) -> () {
    }
}

//
// Storage Ownable
//

// @dev Address of the owner of the contract
@storage_var
func _owner() -> (address: felt) {
}

// @dev Address of the future owner of the contract
@storage_var
func _future_owner() -> (address: felt) {
}

// An event emitted whenever initiate_ownership_transfer() is called.
@event
func owner_change_initiated(current_owner: felt, future_owner: felt) {
}

// An event emitted whenever accept_ownership() is called.
@event
func owner_change_completed(current_owner: felt, future_owner: felt) {
}

//
// Storage Master
//

struct Contributions {
    contributor: felt,
    dev_guild: felt,
    design_guild: felt,
    marcom_guild: felt,
    problem_solver_guild: felt,
    reserach_guild: felt,
    last_timestamp: felt,
}

@storage_var
func _contribution_points(contributor: felt) -> (contributions: Contributions) {
}

@storage_var
func _last_update_time() -> (res: felt) {
}

@storage_var
func _last_update_id() -> (res: felt) {
}

@storage_var
func _merkle_root(id: felt) -> (res: felt) {
}

@storage_var
func _queued_migrations(id: felt) -> (res: felt) {
}

@storage_var
func _dev_guild() -> (res: felt) {
}

@storage_var
func _design_guild() -> (res: felt) {
}

@storage_var
func _marcom_guild() -> (res: felt) {
}

@storage_var
func _problem_solver_guild() -> (res: felt) {
}

@storage_var
func _research_guild() -> (res: felt) {
}

@storage_var
func _initialised() -> (res: felt) {
}

// @notice An event emitted whenever contributions is updated.
@event
func Contributions_updated(id: felt, timestamp: felt) {
}
// @notice An event emitted whenever contributions is migrated.
@event
func Migrated(old_address: felt, new_address: felt) {
}

// @notice An event emitted whenever contributions migration is queued.
@event
func MigrationQueued(old_address: felt, new_address: felt) {
}

// @notice An event emitted whenever queued migration is cancelled.
@event
func MigrationCancelled(old_address: felt, new_address: felt) {
}

//
// Constructor
//
// @notice Contract constructor
// @param owner Initial owner of the contract
// @param symbol Symbol of the pair token
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    with_attr error_message("Master::constructor::owner must be non zero") {
        assert_not_zero(owner);
    }
    _owner.write(owner);
    _last_update_time.write(0);
    _last_update_id.write(0);

    return ();
}

//
// Getters Master
//
// @notice Get contract owner address
// @return owner
@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner) = _owner.read();
    return (owner,);
}

@view
func contribution_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributor: felt
) -> (contribution_points: Contributions) {
    let (contribution_points: Contributions) = _contribution_points.read(contributor=contributor);
    return (contribution_points,);
}

@view
func dev_guild{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res: felt) {
    let (res) = _dev_guild.read();
    return (res,);
}

@view
func design_guild{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res: felt) {
    let (res) = _design_guild.read();
    return (res,);
}

@view
func marcom_guild{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res: felt) {
    let (res) = _marcom_guild.read();
    return (res,);
}

@view
func problem_solver_guild{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res: felt) {
    let (res) = _problem_solver_guild.read();
    return (res,);
}

@view
func research_guild{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res: felt) {
    let (res) = _research_guild.read();
    return (res,);
}

// @Reviewer added for testing
@view
func design_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributor: felt
) -> (design_points: felt) {
    alloc_locals;
    let (contributions: Contributions) = _contribution_points.read(contributor=contributor);
    let design_points: felt = contributions.design_guild;
    return (design_points,);
}

// @notice Get last update time
// @return id
@view
func last_update_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    timestamp: felt
) {
    let (timestamp: felt) = _last_update_time.read();
    return (timestamp,);
}

// @notice Get last update id
// @return id
@view
func last_update_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    id: felt
) {
    let (id: felt) = _last_update_id.read();
    return (id,);
}

// @notice Get last update id
// @return root
@view
func root_by_update_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id :felt) -> (
    res: felt
) {
    let (res: felt) = _merkle_root.read(id);
    return (res,);
}

// @notice Get status of migration hash
// @return res
@view
func queued_migrations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(migration_hash :felt) -> (
    res: felt
) {
    let (res: felt) = _queued_migrations.read(migration_hash);
    return (res,);
}

//
// Setters Ownable
//

// @notice Change ownership to `future_owner`
// @dev Only owner can change. Needs to be accepted by future_owner using accept_ownership
// @param future_owner Address of new owner
@external
func initiate_ownership_transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    future_owner: felt
) -> (future_owner: felt) {
    _only_owner();
    let (current_owner) = _owner.read();
    with_attr error_message("Master::initiate_ownership_transfer::New owner can not be zero") {
        assert_not_zero(future_owner);
    }
    _future_owner.write(future_owner);
    owner_change_initiated.emit(current_owner=current_owner, future_owner=future_owner);
    return (future_owner=future_owner);
}

// @notice Change ownership to future_owner
// @dev Only future_owner can accept. Needs to be initiated via initiate_ownership_transfer
@external
func accept_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (current_owner) = _owner.read();
    let (future_owner) = _future_owner.read();
    let (caller) = get_caller_address();
    with_attr error_message("Master::accept_ownership::Only future owner can accept") {
        assert future_owner = caller;
    }
    _owner.write(future_owner);
    owner_change_completed.emit(current_owner=current_owner, future_owner=future_owner);
    return ();
}

//
// Externals Master
//
// @Notice update guild SBT contracts address.
@external
func initialise{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
    dev_guild: felt, design_guild: felt, marcom_guild: felt, problem_solver_guild: felt, research_guild: felt
) {
    alloc_locals;
    _only_owner();

    let (initialised) = _initialised.read();
    with_attr error_message("Master::initialise::Already initialised") {
        assert initialised = 0;
    }
    
    _design_guild.write(design_guild);
    _dev_guild.write(dev_guild);
    _marcom_guild.write(marcom_guild);
    _problem_solver_guild.write(problem_solver_guild);
    _research_guild.write(research_guild);
    _initialised.write(1);

    return ();
}

@external
func update_contibutions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
    contributions_len: felt, contributions: Contributions*
) {
    alloc_locals;
    _only_owner();

    let (block_timestamp: felt) = get_block_timestamp();
    let (id: felt) = _last_update_id.read();

    _update_contributions_points(contributions_len=contributions_len, contributions=contributions);

    _last_update_id.write(id + 1);
    _last_update_time.write(block_timestamp);

    let (hashed_contributions: felt*) = alloc();
    let (hashed_contributions_len, hashed_contributions) = _hash_contributions(contributions_len, contributions, 0, hashed_contributions);
    
    // @Reviwer calcutaing root instead of passing root as input to make sure that caller
    // does not pass the correct root and still modifies the contribution struct array.
    // @Note the current function can calculate root only if there exactly are 2^n elements 
    // let (_,root) = get_root(hashed_contributions_len, hashed_contributions);
    // _merkle_root.write(id + 1, [root]);

    Contributions_updated.emit(id=id + 1, timestamp=block_timestamp);

    return ();
}

@external
func migrate_points_initiated_by_DAO{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    old_addresses_len: felt, old_addresses: felt*, new_addresses_len: felt, new_addresses: felt*
) {
    alloc_locals;
    _only_owner();
    with_attr error_message("Master::migrate_points::input lengths does not match") {
        assert old_addresses_len = new_addresses_len;
    }

    let (block_timestamp: felt) = get_block_timestamp();

    _migrate_points(old_addresses_len, old_addresses, new_addresses_len, new_addresses);

    // Migrated.emit(old_addresses_len, old_addresses,new_addresses_len, new_addresses);

    return ();
}

@external
func migrate_points_initiated_by_holder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address: felt
) {
    alloc_locals;
   
    let (block_timestamp: felt) = get_block_timestamp();
    let (caller) = get_caller_address();

    let (migration_hash) = hash2{hash_ptr=pedersen_ptr}(caller, new_address);

    _queued_migrations.write(migration_hash, 1);


    MigrationQueued.emit(caller, new_address);

    return ();
}

@external
func execute_migrate_points_initiated_by_holder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    old_address: felt, new_address: felt
) {
    alloc_locals;
     _only_owner();

    let (migration_hash) = hash2{hash_ptr=pedersen_ptr}(old_address, new_address);
    let (is_queued) = _queued_migrations.read(migration_hash);

    with_attr error_message("Master::execute_migrate_points_initiated_by_holder::migration not queued") {
        assert is_queued = 1;
    }

    _queued_migrations.write(migration_hash, 0);

    let (old_addresses: felt*) = alloc();
    assert [old_addresses] = old_address;

    let (new_addresses: felt*) = alloc();
    assert [new_addresses] = new_address;

    _migrate_points(1, old_addresses, 1, new_addresses);

    // Migrated.emit(1, old_addresses, 1, new_addresses);

    return ();
}

@external
func cancel_migrate_points_initiated_by_holder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address: felt
) {
    alloc_locals;

    let (caller) = get_caller_address();
    let (migration_hash) = hash2{hash_ptr=pedersen_ptr}(caller, new_address);

    let (is_queued) = _queued_migrations.read(migration_hash);


    with_attr error_message("Master::cancel_migrate_points_initiated_by_holder::migration not queued") {
        assert is_queued = 1;
    }

    _queued_migrations.write(migration_hash, 0);

    MigrationCancelled.emit(caller, new_address);

    return ();
}

// verifies a merkle proof for a update id
@external
func merkle_verify{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    leaf: felt, update_id: felt, proof_len: felt, proof: felt*
) -> (res: felt) {
    alloc_locals;
    let (root) = _merkle_root.read(update_id);
    let (calc_root) = _calc_merkle_root(leaf, proof_len, proof);

    // check if calculated root is equal to expected
    if (calc_root == root) {
        return (1,);
    } else {
        return (0,);
    }
}
//
// Internal Master
//

func _update_contributions_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributions_len: felt, contributions: Contributions*
) {
    alloc_locals;

    if (contributions_len == 0) {
        return ();
    }

    local new_contributions: Contributions = [contributions];
    local contributor: felt = new_contributions.contributor;

    let old_contributions: Contributions = _contribution_points.read(contributor);

    let (block_timestamp: felt) = get_block_timestamp();

    local updated_contributions: Contributions = Contributions(
        contributor=contributor,
        dev_guild=old_contributions.dev_guild + new_contributions.dev_guild,
        design_guild=old_contributions.design_guild + new_contributions.design_guild,
        marcom_guild=old_contributions.marcom_guild + new_contributions.marcom_guild,
        problem_solver_guild=old_contributions.problem_solver_guild + new_contributions.problem_solver_guild,
        reserach_guild=old_contributions.reserach_guild + new_contributions.reserach_guild,
        last_timestamp=block_timestamp
        );

    _contribution_points.write(contributor, updated_contributions);

    return _update_contributions_points(
        contributions_len=contributions_len - 1, contributions=&contributions[1]
    );
}

func _migrate_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    old_addresses_len: felt, old_addresses: felt*, new_addresses_len: felt, new_addresses: felt*
) {
    alloc_locals;

    if (old_addresses_len == 0) {
        return ();
    }

    let (design_guild) = _design_guild.read();
    let (dev_guild) = _dev_guild.read();
    let (marcom_guild) = _marcom_guild.read();
    let (problem_solver_guild) = _problem_solver_guild.read();
    let (research_guild) = _research_guild.read();

    // local new_contributions: Contributions = [contributions];
    let old_address: felt = [old_addresses];
    let new_address: felt = [new_addresses];

    let old_contributions: Contributions = _contribution_points.read(old_address);

    let (block_timestamp: felt) = get_block_timestamp();

    local zero_contributions: Contributions = Contributions(old_address,0,0,0,0,0,block_timestamp);

    local updated_contributions: Contributions = Contributions(
        contributor=new_address,
        dev_guild=old_contributions.dev_guild,
        design_guild=old_contributions.design_guild,
        marcom_guild=old_contributions.marcom_guild,
        problem_solver_guild=old_contributions.problem_solver_guild,
        reserach_guild=old_contributions.reserach_guild,
        last_timestamp=block_timestamp
        );

    _contribution_points.write(new_address, updated_contributions);
    _contribution_points.write(old_address, zero_contributions);

    // calling migrate on guild SBT contract
    IGuildSBT.migrate_sbt(contract_address = design_guild, old_owner = old_address, new_owner = new_address);
    IGuildSBT.migrate_sbt(contract_address = dev_guild, old_owner = old_address, new_owner = new_address);
    IGuildSBT.migrate_sbt(contract_address = marcom_guild, old_owner = old_address, new_owner = new_address);
    IGuildSBT.migrate_sbt(contract_address = problem_solver_guild, old_owner = old_address, new_owner = new_address);
    IGuildSBT.migrate_sbt(contract_address = research_guild, old_owner = old_address, new_owner = new_address);

    Migrated.emit(old_address, new_address);

    return _migrate_points(
        old_addresses_len = old_addresses_len - 1, old_addresses = &old_addresses[1], new_addresses_len = new_addresses_len - 1, new_addresses = &new_addresses[1]
    );
}

func _hash_contributions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributions_len: felt, contributions: Contributions*, hashed_contributions_len: felt, hashed_contributions: felt*
) -> (
        hashed_contributions_len : felt,
        hashed_contributions : felt*
    ){
    alloc_locals;

    if (contributions_len == 0) {
        return (hashed_contributions_len, hashed_contributions);
    }

    // converting contribution struct to felt*
    let (contribution: felt*) = alloc();
    assert [contribution] = 6;
    assert [contribution + 1] = [contributions].contributor;
    assert [contribution + 2] = [contributions].dev_guild;
    assert [contribution + 3] = [contributions].design_guild;
    assert [contribution + 4] = [contributions].marcom_guild;
    assert [contribution + 5] = [contributions].problem_solver_guild;
    assert [contribution + 6] = [contributions].reserach_guild;

    // hashing the contribution (array)
    let (hashed_contibution) = hash_chain{hash_ptr=pedersen_ptr}(contribution);
    assert hashed_contributions[hashed_contributions_len] = hashed_contibution;
    

    return _hash_contributions(
        contributions_len = contributions_len - 1, contributions = &contributions[1], hashed_contributions_len = hashed_contributions_len + 1, hashed_contributions = hashed_contributions
    );
}

//
// Internals Ownable
//

func _only_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (owner) = _owner.read();
    let (caller) = get_caller_address();
    with_attr error_message("Master::_only_owner::Caller must be owner") {
        assert owner = caller;
    }
    return ();
}

// 
// Internal Merkel
// 

// calculates the merkle root of a given proof
func _calc_merkle_root{pedersen_ptr: HashBuiltin*, range_check_ptr}(
    curr: felt, proof_len: felt, proof: felt*
) -> (res: felt) {
    alloc_locals;

    if (proof_len == 0) {
        return (curr,);
    }

    local node;
    local proof_elem = [proof];
    let le = is_le_felt(curr, proof_elem);

    if (le == 1) {
        let (n) = hash2{hash_ptr=pedersen_ptr}(curr, proof_elem);
        node = n;
    } else {
        let (n) = hash2{hash_ptr=pedersen_ptr}(proof_elem, curr);
        node = n;
    }

    let (res) = _calc_merkle_root(node, proof_len - 1, proof + 1);
    return (res,);
}

// Compute the Merkle root hash of a set of hashes
// func compute_merkle_root{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
//     leaves: felt*, leaves_len: felt
// ) -> (hash: felt*) {
//     alloc_locals;

//     // The trivial case is a tree with a single leaf
//     if (leaves_len == 1) {
//         return (leaves,);
//     }

//     // If the number of leaves is odd then duplicate the last leaf
//     let (_, is_odd) = unsigned_div_rem(leaves_len, 2);
//     if (is_odd == 1) {
//         copy_hash(leaves + HASH_FELT_SIZE * (leaves_len - 1), leaves + HASH_FELT_SIZE * leaves_len);
//     }

//     // Compute the next generation of leaves one level higher up in the tree
//     let (next_leaves) = alloc();
//     let next_leaves_len = (leaves_len + is_odd) / 2;
//     _compute_merkle_root_loop(leaves, next_leaves, next_leaves_len);

//     // Ascend in the tree and recurse on the next generation one step closer to the root
//     return compute_merkle_root(next_leaves, next_leaves_len);
// }

// Compute the next generation of leaves by pairwise hashing
// the previous generation of leaves
// func _compute_merkle_root_loop{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
//     prev_leaves: felt*, next_leaves: felt*, loop_counter
// ) {
//     alloc_locals;

//     // We loop until we've completed the next generation
//     if (loop_counter == 0) {
//         return ();
//     }

//     // Hash two prev_leaves to get one leave of the next generation
//     let (hash) = sha256d_felt_sized(prev_leaves, HASH_FELT_SIZE * 2);
//     copy_hash(hash, next_leaves);

//     // Continue this loop with the next two prev_leaves
//     return _compute_merkle_root_loop(
//         prev_leaves + HASH_FELT_SIZE * 2, next_leaves + HASH_FELT_SIZE, loop_counter - 1
//     );
// }

// // hashes all nodes until it returns a root
// // [1, 2, 3, 4] -> [a, b] -> [r]
// @Reviewer works onlt for 2n elemets size input array
func get_root{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    input_array_len: felt, input_array: felt*
) -> (output_array_len: felt, output_array: felt*) {
    let (output_array: felt*) = alloc();

    let (output_array_len, output_array) = create_next_nodes(
        start=0,
        input_array_len=input_array_len,
        input_array=input_array,
        output_array_len=0,
        output_array=output_array,
    );

    // return as root when exactly one in array
    if (output_array_len == 1) {
        return (1, output_array);
    } else {
        return get_root(output_array_len, output_array);
    }
}

// hashes all nodes to next level in tree
// [1, 2, 3, 4] -> [a, b]
func create_next_nodes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start: felt,
    input_array_len: felt,
    input_array: felt*,
    output_array_len: felt,
    output_array: felt*,
) -> (new_output_array_len: felt, new_output_array: felt*) {
    alloc_locals;

    with_attr error_message("Inputs must have at least a length of two") {
        assert_le(2, input_array_len);
    }

    local index: felt;
    assert index = input_array_len - start;

    let (hash) = hash2{hash_ptr=pedersen_ptr}(
        x=input_array[index - 1], y=input_array[index - 2]
    );
    assert output_array[output_array_len] = hash;

    if (index != 2) {
        return create_next_nodes(
            start + 2, input_array_len, input_array, output_array_len + 1, output_array
        );
    } else {
        return (output_array_len + 1, output_array);
    }
}