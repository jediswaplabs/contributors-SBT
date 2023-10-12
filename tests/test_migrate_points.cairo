use array::{Array, ArrayTrait, SpanTrait};
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };
use tests::utils::{ deployer_addr, user1, user2, user3, user4};
use contributor_SBT2_0::Master::MonthlyContribution;
use contributor_SBT2_0::Master::Contribution;

#[starknet::interface]
trait IMaster<TContractState> {
    fn get_last_update_id(self: @TContractState) -> u32;
    fn get_dev_points(self: @TContractState, contributor: ContractAddress) -> u32;
    fn get_contibutions_points(self: @TContractState, contributor: ContractAddress) -> Contribution;

    fn update_contibutions(ref self: TContractState,  month_id: u32, contributions: Array::<MonthlyContribution>);
    fn migrate_points_initiated_by_DAO(ref self: TContractState, old_addresses: Array::<ContractAddress>, new_addresses: Array::<ContractAddress> );
    fn initialise(ref self: TContractState, dev_guild: ContractAddress, design_guild: ContractAddress, marcom_guild: ContractAddress, problem_solver_guild: ContractAddress, research_guild: ContractAddress);
    fn migrate_points_initiated_by_holder(ref self: TContractState, new_address: ContractAddress);
    fn execute_migrate_points_initiated_by_holder(ref self: TContractState, old_address: ContractAddress, new_address: ContractAddress);

}

#[starknet::interface]
trait IGuildSBT<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn wallet_of_owner(self: @TContractState, account: ContractAddress) -> u256;
    fn get_contribution_tier(self: @TContractState, contributor: ContractAddress) -> u32;
    fn tokenURI(self: @TContractState, token_id: u256) -> Span<felt252>;

    fn safe_mint(ref self: TContractState, token_type: u8);
    
}


fn URI() -> Span<felt252> {
    let mut uri = ArrayTrait::new();

    uri.append('api.jediswap/');
    uri.append('guildSBT/');
    uri.append('dev/');

    uri.span()
}

fn deploy_contracts_and_initialise() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let mut master_constructor_calldata = Default::default();
    Serde::serialize(@deployer_addr(), ref master_constructor_calldata);
    let master_class = declare('Master');
    let master_address = master_class.deploy(@master_constructor_calldata).unwrap();

    // for simplicity deploying all five guild SBTs with same constructors args.
    let name = 'Jedi Dev Guild SBT';
    let symbol = 'JEDI-DEV';
    let mut contribution_levels: Array<u32> = ArrayTrait::new();
    contribution_levels.append(100);
    contribution_levels.append(200);
    contribution_levels.append(500);
    contribution_levels.append(1000);

    let mut guildSBT_constructor_calldata = Default::default();
    Serde::serialize(@name, ref guildSBT_constructor_calldata);
    Serde::serialize(@symbol, ref guildSBT_constructor_calldata);
    Serde::serialize(@URI(), ref guildSBT_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref guildSBT_constructor_calldata);
    Serde::serialize(@master_address, ref guildSBT_constructor_calldata);
    Serde::serialize(@contribution_levels, ref guildSBT_constructor_calldata);

    let guildSBT_class = declare('GuildSBT');

    let dev_guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();
    let design_guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();
    let marcom_guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();
    let problem_solving_guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();
    let research_guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();

    let master_dispatcher = IMasterDispatcher { contract_address: master_address };

    start_prank(master_address, deployer_addr());
    master_dispatcher.initialise(dev_guildSBT_address, design_guildSBT_address, marcom_guildSBT_address, problem_solving_guildSBT_address, research_guildSBT_address);
    stop_prank(master_address);

    

    (master_address, dev_guildSBT_address, design_guildSBT_address, marcom_guildSBT_address, problem_solving_guildSBT_address, research_guildSBT_address)
}

fn update_contribution_and_minting_sbt(master_address: ContractAddress, dev_guildSBT_address: ContractAddress, design_guildSBT_address: ContractAddress, marcom_guildSBT_address: ContractAddress, problem_solving_guildSBT_address: ContractAddress, research_guildSBT_address: ContractAddress) -> (MonthlyContribution, MonthlyContribution) {
    let master_dispatcher = IMasterDispatcher { contract_address: master_address };

    let user1_contribution = MonthlyContribution{ contributor: user1(), dev: 120, design: 250, marcom: 20, problem_solving: 30, research: 10};
    let user2_contribution = MonthlyContribution{ contributor: user2(), dev: 200, design: 30, marcom: 160, problem_solving: 0, research: 50};

    let mut contributions: Array<MonthlyContribution> = ArrayTrait::new();
    contributions.append(user1_contribution);
    contributions.append(user2_contribution);

    start_prank(master_address, deployer_addr());
    master_dispatcher.update_contibutions(092023, contributions);
    stop_prank(master_address);

    let dev_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: dev_guildSBT_address };
    let design_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: design_guildSBT_address };
    let marcom_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: marcom_guildSBT_address };
    
    // minting dev and design SBT for user1
    start_prank(dev_guildSBT_address, user1());
    dev_guildSBT_dispatcher.safe_mint(1);
    stop_prank(dev_guildSBT_address);

    start_prank(design_guildSBT_address, user1());
    design_guildSBT_dispatcher.safe_mint(1);
    stop_prank(design_guildSBT_address);


    // minting dev and marcom SBT for user2
    start_prank(dev_guildSBT_address, user2());
    dev_guildSBT_dispatcher.safe_mint(2);
    stop_prank(dev_guildSBT_address);

    start_prank(marcom_guildSBT_address, user2());
    marcom_guildSBT_dispatcher.safe_mint(2);
    stop_prank(marcom_guildSBT_address);

    // checking the sbt balance for users
    let mut result = dev_guildSBT_dispatcher.balance_of(user1());
    assert(result == 1, '');
    result = design_guildSBT_dispatcher.balance_of(user1());
    assert(result == 1, '');
    result = dev_guildSBT_dispatcher.balance_of(user2());
    assert(result == 1, '');
    result = marcom_guildSBT_dispatcher.balance_of(user2());
    assert(result == 1, '');

    (user1_contribution, user2_contribution)
}

#[test]
fn test_migrate_points_initiated_by_DAO() { 
    let (master_address, dev_guildSBT_address, design_guildSBT_address, marcom_guildSBT_address, problem_solving_guildSBT_address, research_guildSBT_address) = deploy_contracts_and_initialise();
    let (user1_contribution, user2_contribution) = update_contribution_and_minting_sbt(master_address, dev_guildSBT_address, design_guildSBT_address, marcom_guildSBT_address, problem_solving_guildSBT_address, research_guildSBT_address);

    let master_dispatcher = IMasterDispatcher { contract_address: master_address };
    let dev_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: dev_guildSBT_address };
    let design_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: design_guildSBT_address };
    let marcom_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: marcom_guildSBT_address };
    
    // noting the tokenID for user_1
    let user_1_dev_token_id = dev_guildSBT_dispatcher.wallet_of_owner(user1());
    let user_1_design_token_id = design_guildSBT_dispatcher.wallet_of_owner(user1());
    
    // noting the tokenID for user_2
    let user_2_dev_token_id = dev_guildSBT_dispatcher.wallet_of_owner(user2());
    let user_2_marcom_token_id = marcom_guildSBT_dispatcher.wallet_of_owner(user2());
    
    // migrating user1 -> user3 and user2 -> user4
    let mut old_addresses = ArrayTrait::new();
    old_addresses.append(user1());
    old_addresses.append(user2());

    let mut new_addresses = ArrayTrait::new();
    new_addresses.append(user3());
    new_addresses.append(user4());

    start_prank(master_address, deployer_addr());
    master_dispatcher.migrate_points_initiated_by_DAO(old_addresses, new_addresses);
    stop_prank(master_address);


    // verifying points are successfully migrated
    let user3_contribution: Contribution = master_dispatcher.get_contibutions_points(user3());
    assert(user3_contribution.dev == user1_contribution.dev, '');
    assert(user3_contribution.design == user1_contribution.design, '');
    assert(user3_contribution.marcom == user1_contribution.marcom, '');
    assert(user3_contribution.problem_solving == user1_contribution.problem_solving, '');
    assert(user3_contribution.research == user1_contribution.research, '');

    let user4_contribution: Contribution = master_dispatcher.get_contibutions_points(user4());
    assert(user4_contribution.dev == user2_contribution.dev, '');
    assert(user4_contribution.design == user2_contribution.design, '');
    assert(user4_contribution.marcom == user2_contribution.marcom, '');
    assert(user4_contribution.problem_solving == user2_contribution.problem_solving, '');
    assert(user4_contribution.research == user2_contribution.research, '');


    // verfying points of old addresses is resetted to zero
    let user1_contribution_updated: Contribution = master_dispatcher.get_contibutions_points(user1());
    assert(user1_contribution_updated.dev == 0, '');
    assert(user1_contribution_updated.design == 0, '');
    assert(user1_contribution_updated.marcom == 0, '');
    assert(user1_contribution_updated.problem_solving == 0, '');
    assert(user1_contribution_updated.research == 0, '');

    let user2_contribution_updated: Contribution = master_dispatcher.get_contibutions_points(user2());
    assert(user2_contribution_updated.dev == 0, '');
    assert(user2_contribution_updated.design == 0, '');
    assert(user2_contribution_updated.marcom == 0, '');
    assert(user2_contribution_updated.problem_solving == 0, '');
    assert(user2_contribution_updated.research == 0, '');

    // verifying SBTs are transfered
    let mut result = dev_guildSBT_dispatcher.balance_of(user1());
    assert(result == 0, '');
    result = design_guildSBT_dispatcher.balance_of(user1());
    assert(result == 0, '');
    result = dev_guildSBT_dispatcher.balance_of(user2());
    assert(result == 0, '');
    result = marcom_guildSBT_dispatcher.balance_of(user2());
    assert(result == 0, '');

    result = dev_guildSBT_dispatcher.balance_of(user3());
    assert(result == 1, '');
    result = design_guildSBT_dispatcher.balance_of(user3());
    assert(result == 1, '');
    result = dev_guildSBT_dispatcher.balance_of(user4());
    assert(result == 1, '');
    result = marcom_guildSBT_dispatcher.balance_of(user4());
    assert(result == 1, '');

    // verifying correct token id is transfered
    let user_3_dev_token_id = dev_guildSBT_dispatcher.wallet_of_owner(user3());
    let user_3_design_token_id = design_guildSBT_dispatcher.wallet_of_owner(user3());
    
    let user_4_dev_token_id = dev_guildSBT_dispatcher.wallet_of_owner(user4());
    let user_4_marcom_token_id = marcom_guildSBT_dispatcher.wallet_of_owner(user4());

    assert(user_3_dev_token_id == user_1_dev_token_id, '');
    assert(user_3_design_token_id == user_1_design_token_id, '');
    assert(user_4_dev_token_id == user_4_dev_token_id, '');
    assert(user_4_marcom_token_id == user_4_marcom_token_id, '');
    
}

#[test]
fn test_migrate_points_initiated_by_holder() { 
    let (master_address, dev_guildSBT_address, design_guildSBT_address, marcom_guildSBT_address, problem_solving_guildSBT_address, research_guildSBT_address) = deploy_contracts_and_initialise();
    let (user1_contribution, user2_contribution) = update_contribution_and_minting_sbt(master_address, dev_guildSBT_address, design_guildSBT_address, marcom_guildSBT_address, problem_solving_guildSBT_address, research_guildSBT_address);

    let master_dispatcher = IMasterDispatcher { contract_address: master_address };
    let dev_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: dev_guildSBT_address };
    let design_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: design_guildSBT_address };
    let marcom_guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: marcom_guildSBT_address };
    
    // noting the tokenID for user_1
    let user_1_dev_token_id = dev_guildSBT_dispatcher.wallet_of_owner(user1());
    let user_1_design_token_id = design_guildSBT_dispatcher.wallet_of_owner(user1());
    
    // initiating migration request
    start_prank(master_address, user1());
    master_dispatcher.migrate_points_initiated_by_holder(user3());
    stop_prank(master_address);

    // executing migration (by DAO)
    start_prank(master_address, deployer_addr());
    master_dispatcher.execute_migrate_points_initiated_by_holder(user1(), user3());
    stop_prank(master_address);


    // verifying points are successfully migrated
    let user3_contribution: Contribution = master_dispatcher.get_contibutions_points(user3());
    assert(user3_contribution.dev == user1_contribution.dev, '');
    assert(user3_contribution.design == user1_contribution.design, '');
    assert(user3_contribution.marcom == user1_contribution.marcom, '');
    assert(user3_contribution.problem_solving == user1_contribution.problem_solving, '');
    assert(user3_contribution.research == user1_contribution.research, '');

    // verfying points of old addresses is resetted to zero
    let user1_contribution_updated: Contribution = master_dispatcher.get_contibutions_points(user1());
    assert(user1_contribution_updated.dev == 0, '');
    assert(user1_contribution_updated.design == 0, '');
    assert(user1_contribution_updated.marcom == 0, '');
    assert(user1_contribution_updated.problem_solving == 0, '');
    assert(user1_contribution_updated.research == 0, '');


    // verifying SBTs are transfered
    let mut result = dev_guildSBT_dispatcher.balance_of(user1());
    assert(result == 0, '');
    result = design_guildSBT_dispatcher.balance_of(user1());
    assert(result == 0, '');

    result = dev_guildSBT_dispatcher.balance_of(user3());
    assert(result == 1, '');
    result = design_guildSBT_dispatcher.balance_of(user3());
    assert(result == 1, '');

    // verifying correct token id is transfered
    let user_3_dev_token_id = dev_guildSBT_dispatcher.wallet_of_owner(user3());
    let user_3_design_token_id = design_guildSBT_dispatcher.wallet_of_owner(user3());

    assert(user_3_dev_token_id == user_1_dev_token_id, '');
    assert(user_3_design_token_id == user_1_design_token_id, '');

    
}