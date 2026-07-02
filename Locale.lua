-------------------------------------------------------------------------------
--  RemindTalents / Locale.lua
--  Sistema de localização. As chaves são as strings em inglês (base). Locales
--  específicos (ex.: Locales/ptBR.lua) sobrescrevem os valores. Chave sem
--  tradução volta a própria chave (inglês). Carregado ANTES dos demais módulos.
-------------------------------------------------------------------------------
local ADDON, ns = ...

ns.L = setmetatable({}, {
    __index = function(_, key) return key end,
})
