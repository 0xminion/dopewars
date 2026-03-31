use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct WalletState {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub dirty_cash: u32,
    pub clean_cash: u32,
}
