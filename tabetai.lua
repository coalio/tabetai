local tabetai = {
    tokens = {
        keywords = {
            ["elseif"] = "condition",
            ["end"] = "",
            ["for"] = "loop",
            ["function"] = "function",
            ["if"] = "condition"
        }
    },
    pattern = {
        ["a_to_z"] = "[a-zA-Z]",
        ["arrow"] = "%=%>",
        ["between_()"] = "%((.-)%)",
        ["empty_braces"] = "%{%}",
        ["format_word"] = "%s",
        ["format_function_args"] = "function(%s)",
        ["function"] = "function%s*%((.-)%)",
        ["join_by_space"] = "%s %s",
        ["left_brace"] = "%{",
        ["left_parenthesis"] = "%(",
        ["match_word"] = "(%S+)",
        ["right_brace"] = "%}",
        ["right_parenthesis"] = "%)",
        ["equal_sign"] = '^=$'
    }
}

local function init_state()
    _G["state"] = {
        at = 0,
        to = 0,
        ahead = "",
        chunk = nil,
        context = "",
        current = "",
        hold = false,
        look_for = "",
        pending = nil,
        skip = false,
        source = "",
        suspend = false,
        level = 0,
        level_context = {}
    }
end

local function arrow_function()
    local pos = state.to - ((state.pending or ""):len() + (state.pending and state.current or ""):len())
    return (tabetai.pattern["format_function_args"]):format(state.source:match(tabetai.pattern["between_()"], pos))
end

local function keywords()
    if tabetai.tokens.keywords[state.current] then
        state.hold = false
        state.context = tabetai.tokens.keywords[state.current]
    end

    if (state.current:match(tabetai.pattern["between_()"]) or state.current == "function") and state.context == "" then
        state.context = "function"
    end
end

local function operators()
    if state.current:match(tabetai.pattern["arrow"]) then
        state.context = "function"
        state.chunk = arrow_function()
        state.hold = false
    end

    if state.current:match(tabetai.pattern["equal_sign"]) and state.ahead:match(tabetai.pattern["left_brace"]) then
      state.context = "declaration"
      state.chunk = state.current
    end

    if state.current:match(tabetai.pattern["empty_braces"]) then
        state.chunk = state.current
        state.skip = true
    end

    if not state.current:match(tabetai.pattern["function"]) and state.current:gsub(tabetai.pattern["a_to_z"], ""):sub(1, 1) == "(" and state.current:sub(-1, -1) == ")" then
        state.pending = state.current

        return true
    end

    if state.current:match(tabetai.pattern["left_parenthesis"]) and state.skip == false then
        state.hold = true
    end

    if state.current:match(tabetai.pattern["left_brace"]) and state.hold == false and state.skip == false then
        if state.context == "function" or state.context == "loop" or state.context == "condition" then
            state.chunk =
                state.current:gsub(
                "{",
                state.context == "function" and " " or (state.context == "loop" and " do " or " then ")
            )

            if state.context == 'declaration' then
              state.level_context[state.level + 1] = "skip_block"
            else
              state.level_context[state.level + 1] = "block"
            end

            state.context = ""
        end

        state.level = state.level + 1
    end

    if state.current:match("}") and state.hold == false and state.skip == false then
        if state.context == "function"
          or state.context == "loop" 
          or state.context == "condition"
          or state.level_context[state.level] == "block"
          and state.level_context[state.level] ~= "skip_block"
        then
            if state.hold == false then
                state.context = ""
                state.chunk = state.current:gsub("}", " end ")
            end
        end

        state.level_context[state.level] = ""
        state.level = state.level - 1
    end

    if state.current:match("%)") then
        state.hold = false
    end
end

local function next()
    local ret = state.suspend and " " or state.chunk

    state.skip = false
    state.suspend = false
    return ret
end

local function close()
    if state.pending then
        state.source = state.source .. state.pending
    end
end

tabetai.arrow_function = arrow_function
tabetai.close = close
tabetai.keywords = keywords
tabetai.next = next
tabetai.operators = operators
tabetai.strip_comments = strip_comments

return function(code)
    init_state()

    state.source = code
    state.source =
        state.source:gsub(
        (tabetai.pattern["format_word"]):rep(3):format("()", tabetai.pattern["match_word"], "()"),
        function(at, current, to)
            state.at, state.to = at + 1, to - 1
            state.ahead = state.source:match(tabetai.pattern["match_word"], state.to + 1)
            state.chunk = nil
            state.current = current

            tabetai.keywords()
            if tabetai.operators() then return '' end

            if not state.chunk then
                state.chunk = state.current
            end
            if state.current == state.pending then
                state.suspend = true
            end
            if not state.current:match(tabetai.pattern["arrow"]) and state.pending ~= nil then
                state.chunk = (tabetai.pattern["join_by_space"]):format(state.pending, state.chunk)
                state.pending = nil
            elseif state.pending ~= nil then
                state.pending = nil
            end

            return tabetai.next()
        end
    )

    tabetai.close()

    return state.source
end
