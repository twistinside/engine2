/// A collision-bearing reference removed after its first eligible contact.
///
/// A consumable may carry no damage and still disappear against a solid recipient. Entity supplies
/// the deferred-removal implementation; this capability selects when contact requests that removal.
protocol ContactConsumable: Collidable, Destructible {}
