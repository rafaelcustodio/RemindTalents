-------------------------------------------------------------------------------
--  RemindTalents / Locales/ptBR.lua
--  Traduções para Português (Brasil). Só aplica quando o cliente está em ptBR.
-------------------------------------------------------------------------------
if GetLocale() ~= "ptBR" then return end
local ADDON, ns = ...
local L = ns.L

-- Core
L["Disable TalentLoadoutsEx to use RemindTalents (they are incompatible), then type /reload."] =
    "Desative o |cffffd200TalentLoadoutsEx|r para usar o RemindTalents (são incompatíveis) e use /reload."
L["TalentLoadoutsEx is enabled and is incompatible with RemindTalents.\n\nDo you want to import your loadouts from it now?"] =
    "O TalentLoadoutsEx está ativo e é incompatível com o RemindTalents.\n\nDeseja importar os loadouts dele agora?"
L["Migrate"] = "Migrar"
L["Not now"] = "Agora não"
L["Imported %d loadout(s) from TalentLoadoutsEx. Now disable it and use /reload."] =
    "Importados %d loadout(s) do TalentLoadoutsEx. Agora desative-o e use /reload."
L["No TalentLoadoutsEx loadouts found for your class (is it enabled?)."] =
    "Nenhum loadout do TalentLoadoutsEx encontrado para sua classe (ele está ativo?)."
L["Imported (TalentLoadoutsEx)"] = "Importados (TalentLoadoutsEx)"
L["loaded. Open the talent tree to manage loadouts. /rt for help."] =
    "carregado. Abra a árvore de talentos para gerenciar loadouts. /rt para ajuda."
L["inactive: disable TalentLoadoutsEx and use /reload."] =
    "inativo: desative o TalentLoadoutsEx e use /reload."
L["export module unavailable."] = "módulo de exportação indisponível."
L["commands: /rt (talents), /rt save (save current), /rt migrate (import from TalentLoadoutsEx)."] =
    "comandos: |cffffd200/rt|r (talentos), |cffffd200/rt save|r (salvar atual), |cffffd200/rt migrate|r (importar do TalentLoadoutsEx)."

-- Storage
L["could not save (class/spec unavailable)."] = "não foi possível salvar (classe/spec indisponíveis)."

-- Apply
L["could not load the talent interface (Blizzard_PlayerSpells)."] =
    "não foi possível carregar a interface de talentos (Blizzard_PlayerSpells)."
L["could not export the current build."] = "não foi possível exportar o build atual."
L["loadout '%s' saved."] = "loadout '%s' salvo."
L["APIs unavailable."] = "APIs indisponíveis."
L["talent config unavailable."] = "configuração de talentos indisponível."
L["talent tree unavailable."] = "árvore de talentos indisponível."
L["invalid string."] = "string inválida."
L["invalid loadout string."] = "string de loadout inválida."
L["loadout from a different version (recreate the string)."] =
    "loadout de uma versão diferente (recrie a string)."
L["this loadout is for another specialization."] = "este loadout é de outra especialização."
L["could not read the loadout content."] = "não foi possível ler o conteúdo do loadout."
L["cannot change talents in combat."] = "não é possível trocar talentos em combate."
L["cannot change talents here (instance/combat). Change them manually."] =
    "não é possível trocar talentos aqui (instância/combate). Troque manualmente."
L["tree data unavailable."] = "dados da árvore indisponíveis."
L["failed to convert the loadout."] = "falha ao converter o loadout."
L["error applying the loadout; changes reverted."] = "erro ao aplicar o loadout; alterações revertidas."
L["could not confirm the talent change."] = "não foi possível confirmar a troca de talentos."
L["talent interface unavailable."] = "interface de talentos indisponível."

-- Reminder
L["Click to apply this loadout"] = "Clique para aplicar este loadout"
L["Apply: %s"] = "Aplicar: %s"

-- Painel
L["Import loadout"] = "Importar loadout"
L["Name:"] = "Nome:"
L["Paste the code (Copy button on the talent window):"] =
    "Cole o código (botão Copy da janela de talentos):"
L["Import"] = "Importar"
L["Cancel"] = "Cancelar"
L["Import new"] = "Importar novo"
L["Save current loadout"] = "Salvar loadout atual"
L["paste the loadout code."] = "cole o código do loadout."
L["invalid code."] = "código inválido."
L["loadout saved for spec %s."] = "loadout salvo para a spec %s."
L["loadout '%s' imported."] = "loadout '%s' importado."
L["New loadout name:"] = "Novo nome do loadout:"
L["Select a loadout"] = "Selecione um loadout"
L["Zones: %s"] = "Zonas: %s"
L["none"] = "nenhuma"
L["no zone"] = "sem zona"
L["Apply"] = "Aplicar"
L["Zones"] = "Zonas"
L["Rename"] = "Renomear"
L["Delete"] = "Excluir"
L["Change icon"] = "Trocar ícone"
L["Current spec: %s"] = "Spec atual: %s"
L["select a loadout in the list first."] = "selecione um loadout na lista primeiro."
L["Drag to reorder."] = "Arraste para reordenar."

-- Seletor de zonas / catálogo
L["Zones of the loadout"] = "Masmorras e bosses do loadout"
L["Capture current zone"] = "Capturar zona atual"
L["Add"] = "Adicionar"
L["Remove"] = "Remover"
L["enter an instance (dungeon/raid/arena) to capture the zone."] =
    "entre numa instância (masmorra/raid/arena) para capturar a zona."
L["zone '%s' added."] = "zona '%s' adicionada."
L["that zone was already assigned."] = "essa zona já estava atribuída."
L["Assign"] = "Atribuir"
L["Dungeons"] = "Masmorras"
L["Raid: %s"] = "Raid: %s"
L["Old"] = "Antigos"
L[" (old)"] = " (antigo)"
L["No season data yet. Open the Adventure Guide once, then /reload."] =
    "Dados da season indisponíveis. Abra o Guia de Aventuras uma vez e use /reload."
L["Select a dungeon or boss"] = "Selecione uma masmorra ou boss"
L["No loadout assigned"] = "Sem loadout atribuído"
L["Loadout: %s"] = "Loadout: %s"
L["Update from current"] = "Atualizar do atual"
L["Clear"] = "Limpar"
L["Import code"] = "Importar código"
L["use the panel: pick a dungeon/boss, then Save current."] =
    "use o painel: escolha uma masmorra/boss e clique em Salvar atual."
L["Edit"] = "Editar"
L["Active"] = "Ativo"
L["Duplicate"] = "Duplicar"
L["Move to..."] = "Mover para..."
L[" (copy)"] = " (cópia)"
L["Icon"] = "Ícone"
L["Save"] = "Salvar"
L["Loadout"] = "Loadout"
L["Choose icon"] = "Escolher ícone"
L["No loadouts here yet. Use Import or Save current."] =
    "Nenhum loadout aqui. Use Importar ou Salvar atual."
L["Loadouts for: %s"] = "Loadouts de: %s"
L["a name is required."] = "informe um nome."
L["loadout '%s' updated."] = "loadout '%s' atualizado."
L["Paste the talent code (empty = use current build):"] =
    "Cole o código do talento (vazio = usar o build atual):"
L["Difficulty:"] = "Dificuldade:"
L["All"] = "Todas"
L["Normal"] = "Normal"
L["Heroic"] = "Heróico"
L["Mythic"] = "Mítico"
L["LFR"] = "Busca por Raide"

-- Seletor de ícone
L["Choose an icon"] = "Escolher ícone"
L["Search (name or id)"] = "Buscar (nome ou id)"
L["Icon selection is not available in this client."] =
    "A seleção de ícone não está disponível neste cliente."
