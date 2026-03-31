use crate::config::drugs_v2::get_drug_config;

// Calculate how much a dealer sells per tick
pub fn calculate_dealer_sales(
    drug_id: u8,
    quantity: u16,
    salesmanship: u8,
    strategy: u8,       // 0=cautious, 1=aggressive, 2=balanced
    price_tick: u16,
) -> (u16, u32) { // (quantity_sold, revenue)
    let drug_config = get_drug_config(drug_id);
    let price: u32 = drug_config.base_price.into() + (price_tick.into() * drug_config.price_step.into());

    // Sales volume based on strategy and salesmanship
    // cautious: sell 10% of stock, aggressive: 30%, balanced: 20%
    let base_pct: u16 = if strategy == 0 { 10 } else if strategy == 1 { 30 } else { 20 };
    let skill_bonus: u16 = salesmanship.into() / 20; // 0-5 extra %
    let sell_pct: u16 = base_pct + skill_bonus;

    let mut qty_sold: u16 = quantity * sell_pct / 100;
    if qty_sold == 0 && quantity > 0 {
        qty_sold = 1; // sell at least 1
    }
    if qty_sold > quantity {
        qty_sold = quantity;
    }

    let revenue: u32 = price * qty_sold.into();
    (qty_sold, revenue)
}

// Calculate bust risk per tick (returns true if busted)
// risk = location_heat * (100 - stealth) / 10000
// aggressive strategy doubles risk
pub fn calculate_bust_risk(
    location_heat: u8,
    stealth: u8,
    strategy: u8,
    roll: u8,            // VRF random 0-99
) -> bool {
    let base_risk: u16 = location_heat.into() * (100 - stealth.into()) / 100;
    let effective_risk: u16 = if strategy == 1 { base_risk * 2 } else { base_risk };
    // risk is a percentage (0-100)
    roll.into() < effective_risk
}

// Apply commission: dealer keeps commission_pct, owner gets the rest
pub fn apply_commission(revenue: u32, commission_pct: u8) -> (u32, u32) {
    let dealer_cut: u32 = revenue * commission_pct.into() / 100;
    let owner_cut: u32 = revenue - dealer_cut;
    (owner_cut, dealer_cut)
}
