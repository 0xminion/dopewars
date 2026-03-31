#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum GameMode {
    #[default]
    Casual,
    Ranked,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum GameStatus {
    #[default]
    NotStarted,
    InProgress,
    Finished,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum PlayerStatus {
    #[default]
    Normal,
    Jailed,
    Hospitalized,
    Dead,
}
