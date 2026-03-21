-- flurries for iii - boreal ground
print("flurries v0.7")

-- editable parameters
local internal_clock_bpm = 120 -- set starting bpm for internal clock
local run_clock = true -- clock override: stops listening to all clocks if false
local loop_start = 1 -- first step of loop
local loop_end = 16 -- last step of loop
local selected_clock_div = 3 -- default clock multipliers/divider position
local clock_divs = {4, 2, 1, 0.5, 0.25} -- available clock multipliers/dividers
local notes = {66, 68, 70, 72, 74, 76} -- available note array

-- starting parameters
local clock_led = 0
local midi_ppqn = 0
local midi_sync = false
local forwards = true
local current_step = loop_start
local buttons_held = 0
local temp_loop_start = 0
local temp_loop_end = 0
local last_note = 0
local steps = {{0}, {1, 2}, {0}, {4}, {0}, {0}, {5, 6}, {0}, {5, 6, 1, 2}, {0}, {1}, {1, 2}, {1, 2, 3}, {1, 2, 3, 4},
               {0}, {4, 3, 2, 1}}
local ratchet_index = 1

-- MIDI constants
local MIDI_CLOCK = 248
local MIDI_START = 250
local MIDI_STOP = 252

-- FUNCTIONS

-- redraw grid leds
function redraw_grid()
    grid_led_all(0)

    -- ROW 1: menu row
    redraw_grid_menu()

    -- ROW 2: loop row
    redraw_grid_loop()

end

function redraw_grid_menu()
    -- ROW 1: menu row

    -- fill clock divider / multiplier leds
    for i = 1, 5 do
        grid_led(i, 1, 4)
    end

    -- clock led
    if run_clock then
        -- active clock divider / multiplier led blinks on clock running
        grid_led(selected_clock_div, 1, clock_led * 15)
        -- led 16, 1 is dim
        grid_led(16, 1, 4)
    else
        -- inactive clock divider / multiplier led lit when run_clock is false
        grid_led(selected_clock_div, 1, 15)
        -- led 16, 1 is bright
        grid_led(16, 1, 15)
    end

    grid_refresh()
end

function redraw_grid_loop()
    -- ROW 2: loop row

    -- light leds within active loop
    local step_min = math.min(loop_start, loop_end)
    local step_max = math.max(loop_start, loop_end)
    for i = step_min, step_max do
        grid_led(i, 2, 4)
    end

    -- light led for current_step
    if current_step >= 1 and current_step <= 16 then
        grid_led(current_step, 2, 15)
    end

    -- light held start/end button leds for new loop
    if temp_loop_start ~= 0 then
        grid_led(temp_loop_start, 2, 15)
    end
    if temp_loop_end ~= 0 then
        grid_led(temp_loop_end, 2, 15)
    end

    grid_refresh()
end

-- check direction of loop
function check_direction()
    forwards = loop_start <= loop_end
end

-- clock tick function
function tick()
    clock_led = 1 - clock_led

    local step_notes = steps[current_step] or {}
    if #step_notes == 0 then
        step_notes = {0}
    end

    -- get note depending on direction
    local note_index
    if forwards then
        note_index = step_notes[ratchet_index]
    else
        note_index = step_notes[#step_notes - ratchet_index + 1]
    end
    note_index = note_index or 0

    -- turn off previous note
    if last_note > 0 and notes[last_note] then
        midi_note_off(notes[last_note])
        last_note = 0
    end

    -- turn on current note
    if note_index > 0 then
        midi_note_on(notes[note_index])
        last_note = note_index
    end

    -- advance ratchet
    ratchet_index = ratchet_index + 1

    if ratchet_index > #step_notes then
        ratchet_index = 1

        -- advance step after ratchets
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

    redraw_grid()
    -- split out later?
end

-- MAIN SCRIPT

-- initialise internal clock
local base_time = (60 / internal_clock_bpm) * clock_divs[selected_clock_div]
local internal_clock = metro.init(tick, base_time / 4)

-- run internal clock on script launch
check_direction()
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

        -- clock multiplier / divider
        if z == 1 then
            if x >= 1 and x <= 5 then
                selected_clock_div = x -- move LED to pressed button
            end
            local new_time = ((60 / internal_clock_bpm) * clock_divs[selected_clock_div]) / 4
            if internal_clock.time ~= new_time then
                internal_clock.time = new_time
            end
        end

        -- if button 16,1 is pressed: toggles run_clock override
        if x == 16 and z == 1 then

            run_clock = not run_clock
            print("clock running: " .. tostring(run_clock))

            if not run_clock then
                internal_clock:stop()
                if last_note > 0 and notes[last_note] then
                    midi_note_off(notes[last_note])
                end
                last_note = 0
            elseif not midi_sync then
                internal_clock:start()
            end
            redraw_grid_menu()
        end

    elseif y == 2 then
        -- ROW 2: loop row

        -- if two buttons are held, update loop_start and loop_end on release
        if z == 1 then
            -- button pressed
            buttons_held = math.min(buttons_held + 1, 2)

            if buttons_held == 1 then
                temp_loop_start = x
                temp_loop_end = x
            elseif buttons_held == 2 then
                temp_loop_end = x
            end
            redraw_grid_loop()
        else
            -- button released
            buttons_held = math.max(buttons_held - 1, 0)
            -- redraw_grid_loop()

            if buttons_held == 0 and temp_loop_start > 0 and temp_loop_end > 0 then
                loop_start = temp_loop_start
                loop_end = temp_loop_end
                check_direction()

                -- only reset current_step if it is outside of new loop
                if forwards then
                    if current_step < loop_start or current_step > loop_end then
                        current_step = loop_start
                    end
                else
                    if current_step > loop_start or current_step < loop_end then
                        current_step = loop_start
                    end
                end

                print("loop start: " .. temp_loop_start .. " | loop end: " .. temp_loop_end)
                temp_loop_start = 0
                temp_loop_end = 0
                ratchet_index = 1
                redraw_grid_loop()
            end
        end
    end
end

-- midi in event handling
function event_midi(d1, d2, d3)

    -- midi in transport message handling
    if d1 == MIDI_STOP then
        midi_sync = false
        print("midi sync: " .. tostring(midi_sync))
        if run_clock then
            internal_clock:start()
        end
        return

    elseif d1 == MIDI_START then
        -- ignore midi start when run_clock is false
        if run_clock then
            midi_sync = true
            print("midi sync: " .. tostring(midi_sync))
            internal_clock:stop()
            midi_ppqn = 0
            tick()
        end
        return
    elseif d1 == MIDI_CLOCK then
        -- ignore midi clock when run_clock is false
        if run_clock then
            local pulses_per_step = 24 * clock_divs[selected_clock_div]
            local pulses_per_tick = pulses_per_step / 4
            local midi_step_div = math.max(1, math.floor(pulses_per_tick + 0.5))
            midi_sync = true
            midi_ppqn = (midi_ppqn + 1) % midi_step_div
            if midi_ppqn == 0 then
                tick()
            end
        end
        return
    end

    -- midi in note / CC handling
    midi_message(d1, d2, d3)
end

function midi_message(d1, d2, d3)
    -- add further midi in note / CC handling here
end
