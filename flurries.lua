-- flurries for iii - boreal ground
print("flurries v1.0")

-- editable parameters
local internal_clock_bpm = 120 -- set starting bpm for internal clock
local run_clock = true -- run clock on startup
local loop_start = 1 -- starting position for first step of loop
local loop_end = 16 -- starting position for last step of loop
local selected_clock_div = 3 -- starting position within clock_divs
local clock_divs = {4, 2, 1, 0.5, 0.25} -- available clock multipliers/dividers (note: hardcoded to 5 options)
local notes = {60, 62, 64, 65, 67, 69} -- available note array (note: hardcoded to 6 notes)
local substeps_max = 4 -- maximum number of substeps per step
local midi_out_channel = 1 -- midi out channel for notes from grid

-- led brightness settings
local active = 15
local inactive = 6
local disabled = 2

-- parameter initialisation
local midi_sync = false
local clock_led = 0
local forwards = true
local menu_held = false
local current_step = loop_start
local buttons_held = 0
local temp_loop_start = 0
local temp_loop_end = 0
local steps = {{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}}
local last_note = 0
local substep_index = 1
local substep_counter = 0

-- GRID REDRAW FUNCTIONS

-- redraw all grid leds
function redraw_grid()
    grid_led_all(0)

    redraw_grid_menu()
    redraw_grid_loop()
    redraw_grid_steps()

    grid_refresh()
end

-- ROW 1: redraw menu row leds
function redraw_grid_menu()
    -- buttons 1-5,1: draw all divider leds dim
    for i = 1, 5 do
        grid_led(i, 1, inactive)
    end

    -- selected divider led
    local level
    if run_clock then
        -- blink when running
        level = clock_led == 1 and active or 0
    else
        -- fully lit when stopped
        level = active
    end
    grid_led(selected_clock_div, 1, level)

    -- button 16,1: menu button
    grid_led(16, 1, menu_held and active or inactive)
end

-- ROW 2: redraw loop row leds
function redraw_grid_loop()

    -- clear row 2 leds
    for i = 1, 16 do
        grid_led(i, 2, 0)
    end

    -- dimly light leds within active loop
    local step_min = math.min(loop_start, loop_end)
    local step_max = math.max(loop_start, loop_end)
    for i = step_min, step_max do
        grid_led(i, 2, inactive)
    end

    -- light led for current_step
    if current_step >= 1 and current_step <= 16 then
        grid_led(current_step, 2, active)
    end

    -- light held start/end button leds for new loop
    if temp_loop_start ~= 0 then
        grid_led(temp_loop_start, 2, active)
    end
    if temp_loop_end ~= 0 then
        grid_led(temp_loop_end, 2, active)
    end
end

-- ROWS 3 - 8: redraw step leds
function redraw_grid_steps()
    local step_min = math.min(loop_start, loop_end)
    local step_max = math.max(loop_start, loop_end)

    for x = 1, 16 do
        local step_notes = steps[x] or {}

        for i = 1, #notes do
            local y = 9 - i
            local note_num = notes[i]
            local led_state = 0

            -- menu button held: show only bottom row for overview of populated steps
            if menu_held then
                if y == 8 then
                    if #step_notes == 0 or (#step_notes == 1 and step_notes[1] == 0) then
                        led_state = inactive
                    else
                        led_state = active
                    end
                else
                    led_state = 0
                end

                grid_led(x, y, led_state)
            else
                -- menu button not held: display step sequencer
                local is_inside_loop = (x >= step_min and x <= step_max)
                local is_active = false
                local matched = false

                for substep_pos, step_index in ipairs(step_notes) do
                    local n = notes[step_index]

                    if n ~= nil and n == note_num then
                        matched = true

                        if x == current_step and substep_pos == substep_index then
                            is_active = true
                            break
                        end
                    end
                end

                if is_active then
                    led_state = active
                elseif matched then
                    led_state = is_inside_loop and inactive or disabled
                else
                    led_state = 0
                end

                grid_led(x, y, led_state)
            end
        end
    end
end

-- CLOCK TICK FUNCTION
function tick()

    if run_clock then

        clock_led = 1 - clock_led

        local step_notes = steps[current_step] or {}

        -- check sequencer direction for next note
        local note_index
        if forwards then
            note_index = step_notes[substep_index]
        else
            note_index = step_notes[#step_notes - substep_index + 1]
        end
        note_index = note_index or 0

        -- turn off previous note
        if last_note > 0 and notes[last_note] then
            midi_note_off(notes[last_note], 127, midi_out_channel)
            last_note = 0
        end

        -- turn on current note
        if note_index > 0 then
            midi_note_on(notes[note_index], 127, midi_out_channel)
            last_note = note_index
        end

        redraw_grid()

        substep_index = substep_index + 1

        -- when all substeps have been triggered
        if substep_index > #step_notes then
            substep_index = 1

            if forwards then
                current_step = current_step + 1
                if current_step > math.max(loop_start, loop_end) then
                    current_step = math.min(loop_start, loop_end)
                end
            else
                current_step = current_step - 1
                if current_step < math.min(loop_start, loop_end) then
                    current_step = math.max(loop_start, loop_end)
                end
            end
        end

    elseif not run_clock and last_note > 0 then
        midi_note_off(notes[last_note], 127, midi_out_channel)
        last_note = 0
    end
end

-- MAIN SCRIPT

-- initialise internal clock
local internal_clock = metro.init(tick, ((60 / internal_clock_bpm) * clock_divs[selected_clock_div]) / 2)

-- run internal clock on script launch
forwards = loop_start <= loop_end
if run_clock then
    internal_clock:start()
end
redraw_grid()

-- print script start state
print("internal clock bpm: " .. tostring(internal_clock_bpm))
print("midi sync: " .. tostring(midi_sync))
print("clock running: " .. tostring(run_clock))

-- grid button event handling
function event_grid(x, y, z)
    if y == 1 then
        -- ROW 1: menu row

        -- Menu button (16,1)
        if x == 16 then
            menu_held = (z == 1)
            redraw_grid()
            return
        end

        -- clock multiplier / divider buttons (1-5,1)
        if z == 1 then
            if x == selected_clock_div then

                run_clock = not run_clock

                if not run_clock then
                    internal_clock:stop()

                elseif not midi_sync then
                    internal_clock:start()
                end

                redraw_grid()

            elseif x >= 1 and x <= 5 and z == 1 then

                selected_clock_div = x
                local new_time = ((60 / internal_clock_bpm) * clock_divs[selected_clock_div]) / 2
                if internal_clock.time ~= new_time then
                    internal_clock.time = new_time
                end

                redraw_grid_menu()
                grid_refresh()
            end
        end
    end

    if y == 2 then

        -- ROW 2: loop row

        if z == 1 then
            buttons_held = math.min(buttons_held + 1, 2)
            if buttons_held == 1 then
                temp_loop_start = x
                temp_loop_end = x
            elseif buttons_held == 2 then
                temp_loop_end = x
            end

            redraw_grid_loop()
            grid_refresh()

        else

            buttons_held = math.max(buttons_held - 1, 0)

            if buttons_held == 0 and temp_loop_start > 0 and temp_loop_end > 0 then
                loop_start = temp_loop_start
                loop_end = temp_loop_end
                forwards = loop_start <= loop_end

                -- reset current_step if outside new loop
                local step_min = math.min(loop_start, loop_end)
                local step_max = math.max(loop_start, loop_end)
                if current_step < step_min or current_step > step_max then
                    current_step = forwards and step_min or step_max
                end

                print("loop start: " .. temp_loop_start .. " | loop end: " .. temp_loop_end)

                temp_loop_start = 0
                temp_loop_end = 0

                redraw_grid()
            end
        end

    elseif y >= 3 and y <= 8 then

        -- ROWS 3-8: step sequencer rows

        local step = x
        local note_index = 9 - y

        local step_notes = steps[step]

        if menu_held then

            -- don't allow changes to sequence when menu button is held
            if y == 8 and z == 1 then

                steps[step] = {}

                redraw_grid()
            elseif (y > 2 and y < 8) and z == 1 then
                -- reserved for adding further functionality in menu later
                print("this button still needs a purpose assigned")
            end
            return
        end

        if z == 1 then
            -- add new subnotes, overwriting oldest substep once substeps_max is exceeded
            if #step_notes < substeps_max then
                table.insert(step_notes, note_index)
            else
                table.remove(step_notes, 1)
                table.insert(step_notes, note_index)
            end
        end

        redraw_grid()
    end
end

-- midi in event handling
function event_midi(d1, d2, d3)

    -- midi in transport message handling
    if d1 == 252 then -- midi stop
        -- start internal clock on midi stop message
        midi_sync = false
        print("midi sync: " .. tostring(midi_sync))
        if run_clock then
            internal_clock:start()
        end
        return

    elseif d1 == 250 and not midi_sync then -- midi start
        -- stop internal clock and sync on midi start message
        midi_sync = true
        print("midi sync: " .. tostring(midi_sync))
        internal_clock:stop()
        redraw_grid()
        return

    elseif d1 == 248 and midi_sync then -- midi clock
        -- sync to midi clock when run_clock is true
        local pulses_per_tick = (24 * clock_divs[selected_clock_div]) / 2
        substep_counter = substep_counter + 1
        if substep_counter >= pulses_per_tick then
            substep_counter = substep_counter - pulses_per_tick
            tick()
        end
        return
    end

    -- midi in note / CC handling
    midi_message(d1, d2, d3)
end

function midi_message(d1, d2, d3)
    -- add further midi in note / CC handling here
end
