/// Capability for a moving collision body with content-configured missile launch behavior.
protocol MissileLaunching: Collidable, Movable {
    var missileLauncher: MissileLauncherComponent { get }
}

extension MissileLaunching {
    var missileLauncher: MissileLauncherComponent {
        guard let launcher = world.components[MissileLauncherComponent.self][id] else {
            fatalError("There is no missile launcher for the launching entity with ID: \(id)")
        }
        return launcher
    }
}
