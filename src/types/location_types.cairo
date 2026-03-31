#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum LocationId {
    #[default]
    Home,
    Queens,
    Bronx,
    Brooklyn,
    JerseyCity,
    CentralPark,
    ConeyIsland,
}

pub const LOCATION_COUNT: u8 = 6;
