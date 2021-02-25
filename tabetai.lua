local tabetai = {
    context = {
        keywords = {
            ["else"] = "condition_case",
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
        ["between_parentheses"] = "%((.-)%)",
        ["define_directive"] = "#define \"*([%w%s]+)\"* (.-)[\r\n]",
        ["empty_braces"] = "%{%}",
        ["equal_sign"] = "^=$",
        ["format_function_args"] = "function(%s)",
        ["format_word"] = "%s",
        ["function"] = "function%s*%((.-)%)",
        ["include_directive"] = "#include \"(.-)\".-[\r\n]",
        ["join_by_space"] = "%s %s",
        ["left_brace"] = "%{",
        ["left_parenthesis"] = "%(",
        ["match_word"] = "(%S+)",
        ["right_brace"] = "%}",
        ["right_parenthesis"] = "%)",
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

local function preprocessor()
    local directives = {
        ["include"] = function(source)
            local source_file = io.open(source, "r")
            if source_file then
                return source_file:read("*a") .. "\n"
            else
                return "\n"
            end
        end,
        ["define"] = function(find, replace)
            state.source = state.source:gsub("%f[%a]"..find.."%f[%A]", replace)
        end
    }

    state.source = state.source:gsub(tabetai.pattern['include_directive'], directives["include"])

    local next_def = state.source:gmatch(tabetai.pattern['define_directive'])
    ::definitions::
        local find, replace = next_def()
        if not find or not replace then goto exit_definitions end
        directives["define"](find, replace)
    goto definitions
    ::exit_definitions::

    state.source = state.source:gsub(tabetai.pattern['define_directive'], "")
end
local function arrow_function()
    local pos = state.to - ((state.pending or ""):len() + (state.pending and state.current or ""):len())
    return (tabetai.pattern["format_function_args"]):format(state.source:match(tabetai.pattern["between_parentheses"], pos))
end

local function keywords()
    if tabetai.context.keywords[state.current] then
        state.hold = false
        state.context = tabetai.context.keywords[state.current]
    end
end

local function operators()
    if state.current:match(tabetai.pattern["between_parentheses"]) and state.context == "" then
        state.context = "function"
    end

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
        if state.context ~= "" then
            state.chunk =
                state.current:gsub(
                "{",
                (state.context == "function" or state.context == "condition_case") and " "
                or (state.context == "loop" and " do " or " then ")
            )

            if state.context == "declaration" then
              state.level_context[state.level + 1] = "skip_block"
            else
              state.level_context[state.level + 1] = "block"
            end

            state.context = ""
        end

        state.level = state.level + 1
    end

    if state.current:match(tabetai.pattern["right_brace"]) and state.hold == false and state.skip == false then
        if state.context ~= ""
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

    if state.current:match(tabetai.pattern["right_parenthesis"]) then
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
tabetai.preprocessor = preprocessor
tabetai.strip_comments = strip_comments

return function(code)
    init_state()

    state.source = code

    tabetai.preprocessor()

    state.source =
        state.source:gsub(
        (tabetai.pattern["format_word"]):rep(3):format("()", tabetai.pattern["match_word"], "()"),
        function(at, current, to)
            state.at, state.to = at + 1, to - 1
            state.ahead = state.source:match(tabetai.pattern["match_word"], state.to + 1)
            state.chunk = nil
            state.current = current

            tabetai.keywords()
            if tabetai.operators() then return "" end

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
