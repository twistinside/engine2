/// A collision-bearing facade whose first eligible contact applies its configured damage to a recipient.
///
/// Recipients without health remain unaffected. Source consumption is supplied independently by
/// ContactConsumable, so a persistent hazard may deal contact damage without removing itself.
protocol ContactDamaging: Collidable {
    var contactDamage: HitPoints { get }
}

extension ContactDamaging {
    var contactDamage: HitPoints {
        guard let component = world.contactDamageComponents[id] else {
            fatalError("There is no contact damage component for the entity with ID: \(id)")
        }
        return component.amount
    }
}
