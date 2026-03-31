use core::num::traits::Zero;

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum DrugId {
    #[default]
    None,
    Weed,
    Shrooms,
    Acid,
    Ecstasy,
    Speed,
    Heroin,
    Meth,
    Cocaine,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub struct DrugSlot {
    pub drug_id: u8,
    pub quantity: u16,
    pub quality: u8,
    pub effects: u32,
}

impl DrugSlotZeroable of Zero<DrugSlot> {
    fn zero() -> DrugSlot {
        DrugSlot { drug_id: 0, quantity: 0, quality: 0, effects: 0 }
    }
    fn is_zero(self: @DrugSlot) -> bool {
        *self.drug_id == 0 && *self.quantity == 0
    }
    fn is_non_zero(self: @DrugSlot) -> bool {
        *self.drug_id != 0 || *self.quantity != 0
    }
}

pub const DRUG_COUNT: u8 = 8;
pub const MAX_INVENTORY_SLOTS: u8 = 4;
pub const MAX_EFFECTS_PER_DRUG: u8 = 4;
