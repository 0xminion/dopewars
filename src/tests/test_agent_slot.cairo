use rollyourown::systems::helpers::slot_helpers::{
    calculate_dealer_sales, calculate_bust_risk, apply_commission,
};

#[test]
fn test_dealer_sales_cautious() {
    let (qty_sold, _revenue) = calculate_dealer_sales(1, 100, 50, 0, 32);
    // cautious(10%) + skill_bonus(50/20=2) = 12% of 100 = 12
    assert(qty_sold == 12, 'cautious sells 12');
}

#[test]
fn test_dealer_sales_aggressive() {
    let (qty_sold, _revenue) = calculate_dealer_sales(1, 100, 50, 1, 32);
    // aggressive(30%) + 2 = 32% of 100 = 32
    assert(qty_sold == 32, 'aggressive sells 32');
}

#[test]
fn test_dealer_sales_minimum_one() {
    let (qty_sold, _revenue) = calculate_dealer_sales(1, 1, 10, 0, 32);
    // 10% of 1 = 0, but min 1
    assert(qty_sold == 1, 'min sell 1');
}

#[test]
fn test_dealer_sales_revenue() {
    // Weed at tick 32: price = 15 + 32*2 = 79
    let (qty_sold, revenue) = calculate_dealer_sales(1, 100, 0, 0, 32);
    // cautious(10%) + skill(0) = 10% of 100 = 10
    assert(qty_sold == 10, 'sells 10');
    assert(revenue == 790, 'revenue 10*79=790');
}

#[test]
fn test_bust_risk_low_heat() {
    // heat=5, stealth=80, balanced, roll=50
    // risk = 5 * (100-80) / 100 = 1
    // 50 < 1 = false
    let busted = calculate_bust_risk(5, 80, 2, 50);
    assert(!busted, 'low heat no bust');
}

#[test]
fn test_bust_risk_high_heat_aggressive() {
    // heat=50, stealth=20, aggressive, roll=10
    // base = 50 * 80 / 100 = 40, doubled = 80
    // 10 < 80 = true
    let busted = calculate_bust_risk(50, 20, 1, 10);
    assert(busted, 'high heat aggressive busts');
}

#[test]
fn test_commission_split() {
    let (owner, dealer) = apply_commission(1000, 20);
    assert(owner == 800, 'owner gets 800');
    assert(dealer == 200, 'dealer gets 200');
}
