%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from contracts.master import Contributions

@contract_interface
namespace IMaster {
    func last_update_id() -> (res: felt) {
    }

    func update_contibutions(contributions_len: felt, contributions: Contributions*) {
    }
    func design_points(contributor: felt) -> (design_points: felt) {
    }
}

@contract_interface
namespace IGuildSBT {
    func safeMint(type: felt) {
    }

    func balanceOf(owner:felt) -> (res: felt) {
    }
    func wallet_of_owner(owner:felt) -> (res: felt) {
    }

    func tokenURI(tokenId: felt) -> (res: felt) {
    }
    func get_contribution_tier(user: felt) -> (res: felt) {
    }
}

@external
func __setup__() {
    alloc_locals;

    tempvar deployer_address = 123456789;
    tempvar user_1_address = 987654321;
    tempvar user_2_address = 456789123;

    %{
        context.deployer_address = ids.deployer_address
        context.user_1_address = ids.user_1_address
        context.user_2_address = ids.user_2_address
        context.master = deploy_contract("./contracts/master.cairo", [context.deployer_address]).contract_address
        context.guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 117796649871794133531061807, context.master]).contract_address
    %}

    return ();
}

@external
func test_mint_not_enough_contribution_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local deployer_address;
    local master;
    local guildSBT;
    local user_1_address;
    local user_2_address;

    %{
        ids.master = context.master
        ids.deployer_address = context.deployer_address        
        ids.guildSBT = context.guildSBT
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    let (res) = IGuildSBT.balanceOf(contract_address=guildSBT, owner=user_1_address);
    assert res = 0;

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.guildSBT) %}
    %{ expect_revert(error_message="guildSBT::safeMint::Not enough points") %}
    IGuildSBT.safeMint(contract_address=guildSBT, type=1);
    %{ stop_prank() %}


    return();
}

@external
func test_mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local deployer_address;
    local master;
    local guildSBT;
    local user_1_address;
    local user_2_address;

    %{
        ids.master = context.master
        ids.deployer_address = context.deployer_address        
        ids.guildSBT = context.guildSBT
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    let (res) = IGuildSBT.balanceOf(contract_address=guildSBT, owner=user_1_address);
    assert res = 0;

    // %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.guildSBT) %}
    // %{ expect_revert(error_message="guildSBT::safeMint::Not enough points") %}
    // IGuildSBT.safeMint(contract_address=guildSBT, type=1);
    // %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    let (contributions: Contributions*) = alloc();

    local contribution1: Contributions = Contributions(user_1_address, 100, 250, 300, 400, 500, 0);
    local contribution2: Contributions = Contributions(user_2_address, 100, 1200, 300, 400, 500, 0);
    assert [contributions] = contribution1;
    assert [contributions + Contributions.SIZE] = contribution2;

    IMaster.update_contibutions(
        contract_address=master, contributions_len=2, contributions=contributions
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.guildSBT) %}
    IGuildSBT.safeMint(contract_address=guildSBT, type=1);
    %{ stop_prank() %}

    let (res) = IGuildSBT.balanceOf(contract_address=guildSBT, owner=user_1_address);
    assert res = 1;

    // %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.guildSBT) %}
    // %{ expect_revert(error_message="guildSBT::safeMint::Already minted") %}
    // IGuildSBT.safeMint(contract_address=guildSBT, type=1);
    // %{ stop_prank() %}

    let (res1) = IGuildSBT.get_contribution_tier(contract_address=guildSBT, user=user_1_address);
    assert res1 = 2;

    let (user_1_token_id) = IGuildSBT.wallet_of_owner(contract_address = guildSBT, owner = user_1_address);

    let (res1) = IGuildSBT.tokenURI(contract_address=guildSBT, tokenId = user_1_token_id);
    assert res1 = 'api/design/21';

    return ();
}

@external
func test_mint_second_SBT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local deployer_address;
    local master;
    local guildSBT;
    local user_1_address;
    local user_2_address;

    %{
        ids.master = context.master
        ids.deployer_address = context.deployer_address        
        ids.guildSBT = context.guildSBT
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    let (res) = IGuildSBT.balanceOf(contract_address=guildSBT, owner=user_1_address);
    assert res = 0;

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    let (contributions: Contributions*) = alloc();

    local contribution1: Contributions = Contributions(user_1_address, 100, 250, 300, 400, 500, 0);
    local contribution2: Contributions = Contributions(user_2_address, 100, 1200, 300, 400, 500, 0);
    assert [contributions] = contribution1;
    assert [contributions + Contributions.SIZE] = contribution2;

    IMaster.update_contibutions(
        contract_address=master, contributions_len=2, contributions=contributions
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.guildSBT) %}
    IGuildSBT.safeMint(contract_address=guildSBT, type=1);
    %{ stop_prank() %}

    let (res) = IGuildSBT.balanceOf(contract_address=guildSBT, owner=user_1_address);
    assert res = 1;

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.guildSBT) %}
    %{ expect_revert(error_message="guildSBT::safeMint::Already minted") %}
    IGuildSBT.safeMint(contract_address=guildSBT, type=1);
    %{ stop_prank() %}

    return ();
}
