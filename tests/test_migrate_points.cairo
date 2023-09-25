%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from contracts.master import Contributions

@contract_interface
namespace IMaster {
    func initialise(dev_guild: felt, design_guild: felt, marcom_guild: felt, problem_solver_guild: felt, research_guild: felt) {
    }
    func update_contibutions(contributions_len: felt, contributions: Contributions*) {
    }
    func contribution_points(contributor: felt) -> (contribution_points: Contributions) {
    }
    func migrate_points_initiated_by_DAO(old_addresses_len: felt, old_addresses: felt*, new_addresses_len: felt, new_addresses: felt*) {
    }

    func migrate_points_initiated_by_holder(new_address: felt) {
    }
    func cancel_migrate_points_initiated_by_holder(new_address: felt) {
    }
    func execute_migrate_points_initiated_by_holder(old_address: felt, new_address: felt) {
    }
}

@contract_interface
namespace IGuildSBT {
    func get_contribution_tier(user: felt) -> (res: felt) {
    }

    func master() -> (master: felt) {
    }
    func safeMint(type: felt) {
    }
    func balanceOf(owner:felt) -> (res: felt) {
    }
    func wallet_of_owner(owner:felt) -> (res: felt) {
    }
  
}

@external
func __setup__() {
    alloc_locals;

    tempvar deployer_address = 123456789;
    tempvar user_1_address = 987654321;
    tempvar user_2_address = 456789123;
    tempvar user_3_address = 789123456;
    tempvar user_4_address = 321987654;
    tempvar user_5_address = 654321987;

    %{
        context.deployer_address = ids.deployer_address
        context.user_1_address = ids.user_1_address
        context.user_2_address = ids.user_2_address
        context.user_3_address = ids.user_3_address
        context.user_4_address = ids.user_4_address
        context.user_5_address = ids.user_5_address
        context.master = deploy_contract("./contracts/master.cairo", [context.deployer_address]).contract_address
        context.design_guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f64657369676e2f, context.master]).contract_address
        context.dev_guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f6465762f, context.master]).contract_address
        context.marcom_guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f6d6172636f6d2f, context.master]).contract_address
        context.problem_solver_guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f7072, context.master]).contract_address
        context.research_guildSBT = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f72657365617263682f, context.master]).contract_address
    %}

    

    return ();
}

@external
func test_migrate_points_initiated_by_DAO{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;

    local deployer_address;
    local master;
    local design_guildSBT;
    local dev_guildSBT;
    local marcom_guildSBT;
    local problem_solver_guildSBT;
    local research_guildSBT;
    local user_1_address;
    local user_2_address;
    local user_3_address;
    local user_4_address;
    local user_5_address;

    %{
        ids.master = context.master
        ids.deployer_address = context.deployer_address        
        ids.design_guildSBT = context.design_guildSBT
        ids.dev_guildSBT = context.dev_guildSBT
        ids.marcom_guildSBT = context.marcom_guildSBT
        ids.problem_solver_guildSBT = context.problem_solver_guildSBT
        ids.research_guildSBT = context.research_guildSBT
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
        ids.user_3_address = context.user_3_address
        ids.user_4_address = context.user_4_address
        ids.user_5_address = context.user_5_address
    %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}

    let (contributions: Contributions*) = alloc();

    local contribution1: Contributions = Contributions(user_1_address, 100, 250, 300, 0, 0, 0);
    local contribution2: Contributions = Contributions(user_2_address, 500, 1200, 400, 300, 200, 0);
    local contribution3: Contributions = Contributions(user_3_address, 111, 222, 333, 444, 555, 0);
    assert [contributions] = contribution1;
    assert [contributions + Contributions.SIZE] = contribution2;
    assert [contributions + Contributions.SIZE*2] = contribution3;

    IMaster.update_contibutions(
        contract_address=master, contributions_len=3, contributions=contributions
    );
    %{ stop_prank() %}

    // initialising master contract
    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    IMaster.initialise(contract_address=master, dev_guild = dev_guildSBT, design_guild = design_guildSBT, marcom_guild = marcom_guildSBT, problem_solver_guild = problem_solver_guildSBT, research_guild = research_guildSBT);
    %{ stop_prank() %}

    // minting SBT (3/5)
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.design_guildSBT) %}
    IGuildSBT.safeMint(contract_address=design_guildSBT, type=1);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.dev_guildSBT) %}
    IGuildSBT.safeMint(contract_address=dev_guildSBT, type=1);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.marcom_guildSBT) %}
    IGuildSBT.safeMint(contract_address=marcom_guildSBT, type=1);
    %{ stop_prank() %}

    // checking balance of user_1
    let (res) = IGuildSBT.balanceOf(contract_address = dev_guildSBT, owner = user_1_address);
    assert res = 1;
    let (res) = IGuildSBT.balanceOf(contract_address = design_guildSBT, owner = user_1_address);
    assert res = 1;
    let (res) = IGuildSBT.balanceOf(contract_address = marcom_guildSBT, owner = user_1_address);
    assert res = 1;
    let (res) = IGuildSBT.balanceOf(contract_address = problem_solver_guildSBT, owner = user_1_address);
    assert res = 0;
    let (res) = IGuildSBT.balanceOf(contract_address = research_guildSBT, owner = user_1_address);
    assert res = 0;

    // noting the tokenID for user_1
    let (user_1_design_token_id) = IGuildSBT.wallet_of_owner(contract_address = design_guildSBT, owner = user_1_address);
    let (user_1_dev_token_id) = IGuildSBT.wallet_of_owner(contract_address = dev_guildSBT, owner = user_1_address);
    let (user_1_marcom_token_id) = IGuildSBT.wallet_of_owner(contract_address = marcom_guildSBT, owner = user_1_address);

    // migrating points initailed by DAO
    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    let (old_addresses: felt*) = alloc();
    assert [old_addresses] = user_1_address;
    assert [old_addresses + 1] = user_2_address;

    let (new_addresses: felt*) = alloc();
    assert [new_addresses] = user_4_address;
    assert [new_addresses + 1] = user_5_address;
    IMaster.migrate_points_initiated_by_DAO(contract_address=master, old_addresses_len = 2, old_addresses = old_addresses, new_addresses_len = 2, new_addresses = new_addresses);

    %{ stop_prank() %}

    // verifying points are suceesfully migrated
    let(response) = IMaster.contribution_points(contract_address=master, contributor=user_4_address);
    
    assert response.contributor = user_4_address;
    assert response.dev_guild = contribution1.dev_guild;
    assert response.design_guild = contribution1.design_guild;
    assert response.marcom_guild = contribution1.marcom_guild;
    assert response.problem_solver_guild = contribution1.problem_solver_guild;
    assert response.reserach_guild = contribution1.reserach_guild;

    // verfying points of user_1 is resetted to zero
    let(response) = IMaster.contribution_points(contract_address=master, contributor=user_1_address);
    
    assert response.contributor = user_1_address;
    assert response.dev_guild = 0;
    assert response.design_guild = 0;
    assert response.marcom_guild = 0;
    assert response.problem_solver_guild = 0;
    assert response.reserach_guild = 0;


    // verfying points of user_3 is still intact(not affected)
    let(response) = IMaster.contribution_points(contract_address=master, contributor=user_3_address);
    
    assert response.contributor = user_3_address;
    assert response.dev_guild = contribution3.dev_guild;
    assert response.design_guild = contribution3.design_guild;
    assert response.marcom_guild = contribution3.marcom_guild;
    assert response.problem_solver_guild = contribution3.problem_solver_guild;
    assert response.reserach_guild = contribution3.reserach_guild;

    // Verifying the balance of user_1 updated
    let (res) = IGuildSBT.balanceOf(contract_address = dev_guildSBT, owner = user_1_address);
    assert res = 0;
    let (res) = IGuildSBT.balanceOf(contract_address = design_guildSBT, owner = user_1_address);
    assert res = 0;
    let (res) = IGuildSBT.balanceOf(contract_address = marcom_guildSBT, owner = user_1_address);
    assert res = 0;

    // balance of user_4 updated
    let (res) = IGuildSBT.balanceOf(contract_address = dev_guildSBT, owner = user_4_address);
    assert res = 1;
    let (res) = IGuildSBT.balanceOf(contract_address = design_guildSBT, owner = user_4_address);
    assert res = 1;
    let (res) = IGuildSBT.balanceOf(contract_address = marcom_guildSBT, owner = user_4_address);
    assert res = 1;

    // verifying correct token id is transfered
    let (user_4_design_token_id) = IGuildSBT.wallet_of_owner(contract_address = design_guildSBT, owner = user_4_address);
    let (user_4_dev_token_id) = IGuildSBT.wallet_of_owner(contract_address = dev_guildSBT, owner = user_4_address);
    let (user_4_marcom_token_id) = IGuildSBT.wallet_of_owner(contract_address = marcom_guildSBT, owner = user_4_address);

    assert user_1_dev_token_id = user_4_dev_token_id;
    assert user_1_design_token_id = user_4_design_token_id;
    assert user_1_marcom_token_id = user_4_marcom_token_id;
    return ();
}


@external
func test_migrate_points_initiated_by_holder{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;

    local deployer_address;
    local master;
    local design_guildSBT;
    local dev_guildSBT;
    local marcom_guildSBT;
    local problem_solver_guildSBT;
    local research_guildSBT;
    local user_1_address;
    local user_2_address;


    %{
        ids.master = context.master
        ids.deployer_address = context.deployer_address        
        ids.design_guildSBT = context.design_guildSBT
        ids.dev_guildSBT = context.dev_guildSBT
        ids.marcom_guildSBT = context.marcom_guildSBT
        ids.problem_solver_guildSBT = context.problem_solver_guildSBT
        ids.research_guildSBT = context.research_guildSBT        
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    // initialising master contract
    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    IMaster.initialise(contract_address=master, dev_guild = dev_guildSBT, design_guild = design_guildSBT, marcom_guild = marcom_guildSBT, problem_solver_guild = problem_solver_guildSBT, research_guild = research_guildSBT);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}

    let (contributions: Contributions*) = alloc();

    local contribution1: Contributions = Contributions(user_1_address, 100, 250, 300, 400, 500, 0);
    assert [contributions] = contribution1;

    IMaster.update_contibutions(
        contract_address=master, contributions_len=1, contributions=contributions
    );
    %{ stop_prank() %}


//  initiating migrating points
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.master) %}
    let new_address = user_2_address;
    IMaster.migrate_points_initiated_by_holder(contract_address=master, new_address = new_address);

    %{ stop_prank() %}


    // executing migration (by DAO)
    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    let old_address = user_1_address;
    let new_address = user_2_address;
    IMaster.execute_migrate_points_initiated_by_holder(contract_address=master, old_address = old_address, new_address = new_address);

    %{ stop_prank() %}
    // verifying points are suceesfully migrated
    let(response) = IMaster.contribution_points(contract_address=master, contributor=user_2_address);
    
    assert response.contributor = user_2_address;
    assert response.dev_guild = contribution1.dev_guild;
    assert response.design_guild = contribution1.design_guild;
    assert response.marcom_guild = contribution1.marcom_guild;
    assert response.problem_solver_guild = contribution1.problem_solver_guild;
    assert response.reserach_guild = contribution1.reserach_guild;

    // verfying points of user_1 is resetted to zero
    let(response) = IMaster.contribution_points(contract_address=master, contributor=user_1_address);
    
    assert response.contributor = user_1_address;
    assert response.dev_guild = 0;
    assert response.design_guild = 0;
    assert response.marcom_guild = 0;
    assert response.problem_solver_guild = 0;
    assert response.reserach_guild = 0;


    return ();
}

@external
func test_cancel_migrate_points_initiated_by_holder{
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
        ids.guildSBT = context.design_guildSBT
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}

    let (contributions: Contributions*) = alloc();

    local contribution1: Contributions = Contributions(user_1_address, 100, 250, 300, 400, 500, 0);
    assert [contributions] = contribution1;

    IMaster.update_contibutions(
        contract_address=master, contributions_len=1, contributions=contributions
    );
    %{ stop_prank() %}


    // initiating migrating points (by holder itself)
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.master) %}
    let new_address = user_2_address;
    IMaster.migrate_points_initiated_by_holder(contract_address=master, new_address = new_address);

    %{ stop_prank() %}


    // cancelling migrating points (by holder itself)
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.master) %}
    let new_address = user_2_address;
    IMaster.cancel_migrate_points_initiated_by_holder(contract_address=master, new_address = new_address);

    %{ stop_prank() %}

    // executing migration (by DAO)
    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.master) %}
    let old_address = user_1_address;
    let new_address = user_2_address;
    %{ expect_revert(error_message="Master::execute_migrate_points_initiated_by_holder::migration not queued") %}
    IMaster.execute_migrate_points_initiated_by_holder(contract_address=master, old_address = old_address, new_address = new_address);

    %{ stop_prank() %}

    return ();
}