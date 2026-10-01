BotRPPlayerConfig = {
    Version = '1.0.0',

    -- State is kept in memory by default.
    -- Persistence will be provided by a separate storage adapter.
    Defaults = {
        money = {
            cash = 0,
            bank = 0
        },
        metadata = {
            hunger = 100,
            thirst = 100,
            stress = 0
        },
        permissions = {
            group = 'user'
        }
    }
}
