// @title Mesh Contributor SBTs Master Cairo 2.2
// @author Mesh Finance
// @license MIT
// @notice Master to store contribution points

use starknet::ContractAddress;
use zeroable::Zeroable;
use array::{Array, ArrayTrait, SpanTrait};
use serde::Serde;
use traits::{Into, TryInto};
use alexandria_storage::list::{List, ListTrait};



#[derive(Drop, Serde, starknet::Store)]
struct GuildPoints {
    // @notice the cummulative score for each contributor
    cum_score: u32,
    // @notice Montly points for contribution for eg [Sept_2023 -> 250] will be written as [092023, 250]
    // even index as month_id, immediate right is points in that month
    data: List::<u32>
}

#[derive(Drop, Serde, starknet::Store)]
struct Contribution {
    // @notice Contribution for dev guild
    dev: GuildPoints,
    // @notice Contribution for design guild
    design: GuildPoints,
    // @notice Contribution for problem solving guild
    problem_solving: GuildPoints,
    // @notice Contribution for marcom guild
    marcom: GuildPoints,
    // @notice Contribution for research guild
    research: GuildPoints,
    // @notice timestamp for the last update
    last_timestamp: u64
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct MontlyContribution {
    // @notice Contributor Address, used in update_contribution function
    contributor: ContractAddress,
    // @notice Contribution for dev guild
    dev: u32,
    // @notice Contribution for design guild
    design: u32,
    // @notice Contribution for problem solving guild
    problem_solving: u32,
    // @notice Contribution for marcom guild
    marcom: u32,
    // @notice Contribution for research guild
    research: u32
    
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct TotalMontlyContribution {
    // @notice Montly contribution for dev guild
    dev: u32,
    // @notice Montly contribution for design guild
    design: u32,
    // @notice Montly contribution for problem solving guild
    problem_solving: u32,
    // @notice Montly contribution for marcom guild
    marcom: u32,
    // @notice Montly contribution for research guild
    research: u32
}

//
// External Interfaces
//


#[starknet::interface]
trait IGuild<T> {
    fn migrate_sbt(ref self: T, old_address: ContractAddress, new_address: ContractAddress);
}


//
// Contract Interface
//
#[starknet::interface]
trait IMaster<TContractState> {
    // view functions
    fn get_contibutions_points(self: @TContractState, contributor: ContractAddress) -> Contribution;
    fn get_dev_points(self: @TContractState, contributor: ContractAddress) -> GuildPoints;
    fn get_design_points(self: @TContractState, contributor: ContractAddress) -> GuildPoints;
    fn get_problem_solving_points(self: @TContractState, contributor: ContractAddress) -> GuildPoints;
    fn get_marcom_points(self: @TContractState, contributor: ContractAddress) -> GuildPoints;
    fn get_research_points(self: @TContractState, contributor: ContractAddress) -> GuildPoints;

    // external functions
    fn update_contibutions(ref self: TContractState,  month_id: u32, contributions: Array::<MontlyContribution>);
    fn initialise(ref self: TContractState, dev_guild: ContractAddress, design_guild: ContractAddress, marcom_guild: ContractAddress, problem_solver_guild: ContractAddress, research_guild: ContractAddress);
    fn migrate_points_initiated_by_DAO(ref self: TContractState, old_addresses: Array::<ContractAddress>, new_addresses: Array::<ContractAddress>);
    fn migrate_points_initiated_by_holder(ref self: TContractState, new_address: ContractAddress);
    fn execute_migrate_points_initiated_by_holder(ref self: TContractState, old_address: ContractAddress, new_address: ContractAddress);


}


#[starknet::contract]
mod Master {
    use traits::Into; // TODO remove intos when u256 inferred type is available
    use option::OptionTrait;
    use array::{ArrayTrait, SpanTrait};
    use result::ResultTrait;
    use zeroable::Zeroable;
    use hash::LegacyHash;
    use contributor_SBT2_0::access::ownable::{Ownable, IOwnable};
    use contributor_SBT2_0::access::ownable::Ownable::{
        ModifierTrait as OwnableModifierTrait, InternalTrait as OwnableInternalTrait,
    };
    use starknet::{ContractAddress, ClassHash, SyscallResult, SyscallResultTrait, get_caller_address, get_contract_address, get_block_timestamp, contract_address_const};
    use integer::{u128_try_from_felt252, u256_sqrt, u256_from_felt252};
    use starknet::syscalls::{replace_class_syscall, call_contract_syscall};
    use alexandria_storage::list::{List, ListTrait};
    use super::{GuildPoints, Contribution, MontlyContribution, TotalMontlyContribution};
    use super::{
        IGuildDispatcher, IGuildDispatcherTrait
    };


    //
    // Storage Pair
    //
    #[storage]
    struct Storage {
        _contributions:  LegacyMap::<ContractAddress, Contribution>, // @dev contributions
        _total_contribution: LegacyMap::<u32, TotalMontlyContribution>, // @dev total contribution month wise [month_id => points]
        _last_update_id: u32, // @dev contribution update id
        _last_update_time: u64, // @dev timestamp for last update
        _dev_guild_SBT: ContractAddress, // @dev contract address for dev guild SBTs
        _design_guild_SBT: ContractAddress, // @dev contract address for design guild guild SBTs
        _marcom_guild_SBT: ContractAddress, // @dev contract address for marcom guild SBTs
        _problem_solving_guild_SBT: ContractAddress, // @dev contract address for problem solving guild SBTs
        _research_guild_SBT: ContractAddress, // @dev contract address for research guild SBTs
        _initialised: u8, // @dev Flag to store initialisation state
        _queued_migrations: LegacyMap::<felt252, u8>, // @dev flag to store queued migration requests.
        // _klast: u256, // @dev reserve0 * reserve1, as of immediately after the most recent liquidity event
        // _locked: bool, // @dev Boolean to check reentrancy
        // _factory: ContractAddress, // @dev Factory contract address
        // Proxy_admin: ContractAddress, // @dev Admin contract address, to be used till we finalize Cairo upgrades.
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContributionUpdated: ContributionUpdated,
        MigrationQueued: MigrationQueued,
        Migrated: Migrated,
        // Swap: Swap,
        // Sync: Sync
    }

    // @notice An event emitted whenever contribution is updated
    #[derive(Drop, starknet::Event)]
    struct ContributionUpdated {
        update_id: u32, 
        contributor: ContractAddress,
        month_id: u32,
        points_earned: MontlyContribution
    }

    // @notice An event emitted whenever migration is queued
    #[derive(Drop, starknet::Event)]
    struct MigrationQueued {
        old_address: ContractAddress, 
        new_address: ContractAddress, 
        hash: felt252
    }

    // @notice An event emitted whenever SBT is migrated
    #[derive(Drop, starknet::Event)]
    struct Migrated {
        old_address: ContractAddress, 
        new_address: ContractAddress
    }


    //
    // Constructor
    //

    // @notice Contract constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner_: ContractAddress,) {
        // @notice not sure if default is already zero or need to initialise.
        self._last_update_id.write(0_u32);
        self._last_update_time.write(0_u64);
        self._initialised.write(0_u8);

        let mut ownable_self = Ownable::unsafe_new_contract_state();
        ownable_self._transfer_ownership(new_owner: owner_);

    }

    #[external(v0)]
    impl Master of super::IMaster<ContractState> {
        //
        // Getters
        //
        fn get_contibutions_points(self: @ContractState, contributor: ContractAddress) -> Contribution {
            self._contributions.read(contributor)
        }

        fn get_dev_points(self: @ContractState, contributor: ContractAddress) -> GuildPoints {
            let contribution = self._contributions.read(contributor);
            contribution.dev
        }

        fn get_dev_points(self: @ContractState, contributor: ContractAddress) -> GuildPoints {
            let contribution = self._contributions.read(contributor);
            contribution.dev
        }


        //
        // Setters
        //

        fn initialise(ref self: ContractState, dev_guild: ContractAddress, design_guild: ContractAddress, marcom_guild: ContractAddress, problem_solver_guild: ContractAddress, research_guild: ContractAddress) {
            self._only_owner();
            let is_initialised = self._initialised.read();
            assert (is_initialised == 0, "ALREADY_INITIALISED");

            self._dev_guild_SBT.write(dev_guild);
            self._design_guild_SBT.write(design_guild);
            self._marcom_guild_SBT.write(marcom_guild);
            self._problem_solving_guild_SBT.write(problem_solver_guild);
            self._research_guild_SBT.write(research_guild);
            self._initialised.write(1_u8);
        }

        fn update_contibutions(ref self: ContractState, month_id: u32, contributions: Array::<MontlyContribution>) {
            self._only_owner();
            let block_timestamp = get_block_timestamp();
            let id = self._last_update_id.read();
            let mut current_index = 0;

            // for keeping track of cummulative guild points for that month.
            let mut dev_total_cum = 0.into();
            let mut design_total_cum = 0.into();
            let mut problem_solving_total_cum = 0.into();
            let mut marcom_total_cum = 0.into();
            let mut research_total_cum = 0.into();

            loop {
                if (current_index == contributions.len() - 1) {
                    break true;
                }
                let new_contributions = *contributions[current_index];
                let contributor:ContractAddress = new_contributions.contributor;
                // let points = new_contributions.points;
                // let mut points_index = 0;

                // loop {
                //     if (points_index == 4) {
                //         break true;
                //     }
                //     let contribution_point = *points[points_index];
                //     if (contribution_point == 0) {
                //         continue true;
                //         }
                //     }

                let old_contribution = self._contributions.read(contributor);
                let mut list:ListTrait = ListTrait::new();

                let old_dev_contribution = old_contribution.dev;
                let contribution_data_dev = old_dev_contribution.data;
                let mut cum_score_dev = old_dev_contribution.cum_score;
                if (new_contributions.dev != 0) {
                    
                    list.append(contribution_data_dev, month_id);
                    list.append(contribution_data_dev, new_contributions.dev);

                    cum_score_dev = cum_score_dev + new_contributions.dev;

                    dev_total_cum = dev_total_cum + new_contributions.dev;
                }
                let new_dev_contribution = GuildPoints{cum_score: cum_score_dev, data: contribution_data_dev};


                let old_design_contribution = old_contribution.design;
                let contribution_data_design = old_design_contribution.data;
                let mut cum_score_design = old_design_contribution.cum_score;
                if (new_contributions.design != 0) {
                    
                    list.append(contribution_data_design, month_id);
                    list.append(contribution_data_design, new_contributions.design);
                    // contribution_data_design.append(month_id);
                    // contribution_data_design.append(new_contributions.design);
                    
                    cum_score_design = cum_score_design + new_contributions.design;

                    design_total_cum = design_total_cum + new_contributions.design;
                }
                let new_design_contribution = GuildPoints{cum_score: cum_score_design, data: contribution_data_design};


                let old_problem_solving_contribution = old_contribution.problem_solving;
                let contribution_data_problem_solving = old_problem_solving_contribution.data;
                let mut cum_score_problem_solving = old_problem_solving_contribution.cum_score;
                if (new_contributions.problem_solving != 0) {
                    
                    list.append(contribution_data_problem_solving, month_id);
                    list.append(contribution_data_problem_solving, new_contributions.problem_solving);
                    // contribution_data_problem_solving.append(month_id);
                    // contribution_data_problem_solving.append(new_contributions.problem_solving);

                    cum_score_problem_solving = cum_score_problem_solving + new_contributions.problem_solving;

                    problem_solving_total_cum = problem_solving_total_cum + new_contributions.problem_solving;
                }
                let new_problem_solving_contribution = GuildPoints{cum_score: cum_score_problem_solving, data: contribution_data_problem_solving};


                let old_marcom_contribution = old_contribution.marcom;
                let contribution_data_marcom = old_marcom_contribution.data;
                let mut cum_score_marcom = old_marcom_contribution.cum_score;
                if (new_contributions.marcom != 0) {
                    
                    list.append(contribution_data_marcom, month_id);
                    list.append(contribution_data_marcom, new_contributions.marcom);
                    // contribution_data_marcom.append(month_id);
                    // contribution_data_marcom.append(new_contributions.marcom);

                    cum_score_marcom = cum_score_marcom + new_contributions.marcom;
                    marcom_total_cum = marcom_total_cum + new_contributions.marcom;                    
                }
                let new_marcom_contribution = GuildPoints{cum_score: cum_score_marcom, data: contribution_data_marcom};


                let old_research_contribution = old_contribution.research;
                let contribution_data_research = old_research_contribution.data;
                let mut cum_score_research = old_research_contribution.cum_score;
                if (new_contributions.research != 0) {
                    
                    list.append(contribution_data_research, month_id);
                    list.append(contribution_data_research, new_contributions.research);
                    // contribution_data_research.append(month_id);
                    // contribution_data_research.append(new_contributions.research);
                    
                    cum_score_research = cum_score_research + new_contributions.research;

                    research_total_cum = research_total_cum + new_contributions.research;
                }
                let new_research_contribution = GuildPoints{cum_score: cum_score_research, data: contribution_data_research};


                let updated_contribution = Contribution{dev: new_dev_contribution, design: new_design_contribution, problem_solving: new_problem_solving_contribution, marcom: new_marcom_contribution, research: new_research_contribution, last_timestamp: block_timestamp};
                self._contributions.write(contributor, updated_contribution);

                let total_monthy_contribution = TotalMontlyContribution{dev: dev_total_cum, design: design_total_cum, problem_solving: problem_solving_total_cum, marcom: marcom_total_cum, research: research_total_cum};
                self._total_contribution.write(month_id, total_monthy_contribution);
                current_index += 1;
                // }
                self.emit(ContributionUpdated{update_id: id, contributor: contributor, month_id: month_id, points_earned: new_contributions});

            };
            id += 1;
            self._last_update_id.write(id);

        }


        fn migrate_points_initiated_by_DAO(ref self: ContractState, old_addresses: Array::<ContractAddress>, new_addresses: Array::<ContractAddress> ) {
            self._only_owner();
            assert(old_addresses.len() == new_addresses.len(), "INVALID_INPUTS");
            let mut current_index = 0;

            loop {
                if (current_index == old_addresses.len() - 1) {
                    break true;
                }
                InternalImpl::_migrate_points(ref self, *old_addresses[current_index], *new_addresses[current_index]);
                current_index += 1;
            };

        }


        fn migrate_points_initiated_by_holder(ref self: ContractState, new_address: ContractAddress) {
            let caller = get_caller_address();
            let migration_hash: felt252 = LegacyHash::hash(caller.into(), new_address);

            self._queued_migrations.write(migration_hash, 1_u8);

            self.emit(MigrationQueued { old_address: caller, new_address: new_address, hash: migration_hash});

        }

        fn execute_migrate_points_initiated_by_holder(ref self: ContractState, old_address: ContractAddress, new_address: ContractAddress) {
            self._only_owner();
            let migration_hash: felt252 = LegacyHash::hash(old_address.into(), new_address);
            let is_queued = self._queued_migrations.read(migration_hash);

            assert(is_queued == 1, "NOT_QUEUED");

            self._queued_migrations.write(migration_hash, 0_u8);
            InternalImpl::_migrate_points(ref self, old_address, new_address);

        }




    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        //
        // Internals
        //

        fn _migrate_points(ref self: ContractState, old_address: ContractAddress, new_address: ContractAddress) {

            let design_guild = self._design_guild_SBT.read();
            let dev_guild = self._dev_guild_SBT.read();
            let problem_solver_guild = self._problem_solving_guild_SBT.read();
            let marcom_guild = self._marcom_guild_SBT.read();
            let research_guild = self._research_guild_SBT.read();

            let contribution = self._contributions.read(old_address);

            let zero_contribution = Contribution{dev: GuildPoints{ cum_score: 0_u32, data: ListTrait::new()},
                                                 design: GuildPoints{ cum_score: 0_u32, data: ListTrait::new()},
                                                 problem_solving: GuildPoints{ cum_score: 0_u32, data: ListTrait::new()},
                                                 marcom: GuildPoints{ cum_score: 0_u32, data: ListTrait::new()},
                                                 research: GuildPoints{ cum_score: 0_u32, data: ListTrait::new()},
                                                 last_timestamp: 0_u64
                                                };

            self._contributions.write(old_address, zero_contribution);
            self._contributions.write(new_address, contribution);

            let dev_guildDispatcher = IGuildDispatcher { contract_address: dev_guild };
            dev_guildDispatcher.migrate_sbt(old_address, new_address);

            let design_guildDispatcher = IGuildDispatcher { contract_address: design_guild };
            design_guildDispatcher.migrate_sbt(old_address, new_address);

            let problem_solver_guildDispatcher = IGuildDispatcher { contract_address: problem_solver_guild };
            problem_solver_guildDispatcher.migrate_sbt(old_address, new_address);

            let marcom_guildDispatcher = IGuildDispatcher { contract_address: marcom_guild };
            marcom_guildDispatcher.migrate_sbt(old_address, new_address);

            let research_guildDispatcher = IGuildDispatcher { contract_address: research_guild };
            research_guildDispatcher.migrate_sbt(old_address, new_address);

            self.emit(Migrated{old_address: old_address, new_address: new_address});

        }

    }



    #[generate_trait]
    impl ModifierImpl of ModifierTrait {
        fn _only_owner(self: @ContractState) {
            let mut ownable_self = Ownable::unsafe_new_contract_state();

            ownable_self.assert_only_owner();
        }
    }

    #[external(v0)]
    impl IOwnableImpl of IOwnable<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let ownable_self = Ownable::unsafe_new_contract_state();

            ownable_self.owner()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let mut ownable_self = Ownable::unsafe_new_contract_state();

            ownable_self.transfer_ownership(:new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            let mut ownable_self = Ownable::unsafe_new_contract_state();

            ownable_self.renounce_ownership();
        }
    }

 

}

