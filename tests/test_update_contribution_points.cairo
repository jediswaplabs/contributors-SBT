%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

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
    func get_contribution_tier(user: felt) -> (res: felt) {
    }

    func master() -> (master: felt) {
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
        context.guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f64657369676e2f, context.master]).contract_address
    %}

    return ();
}

@external
func test_update_contribution_points{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
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

    let (res) = IMaster.last_update_id(contract_address=master);
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

    let (res) = IMaster.last_update_id(contract_address=master);
    assert res = 1;

    let (res) = IGuildSBT.get_contribution_tier(contract_address=guildSBT, user=user_1_address);
    assert res = 2;

    let (res) = IGuildSBT.get_contribution_tier(contract_address=guildSBT, user=user_2_address);
    assert res = 5;

    // let (res) = IMaster.design_points(contract_address=master, contributor = user_2_address)
    // assert res = 1200

    return ();
}
