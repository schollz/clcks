-- xxx v0.1
-- tempo-locked repeat
--
-- llllllll.co/t/xxx
--
--
--
--    ▼ instructions below ▼
--
-- press K2 or K3 to activate
-- press K2 or K3 to deactivate
-- (K2 keeps monitoring audio)
-- E1 changes repeat number
-- E2&E2 change final level&rate
--
-- hold K1 to shift
-- shift+E2 changes bpm
-- shift+E3 changes beat subdivision
-- shift+K2 resets parameters
-- shift+K3 randomizes
--
--

state_activated=false
state_current_time=0
state_repeat_number=0
state_beat_number=0
state_current_position=0
state_shift=false
state_tick=false

flag_update_screen=false

param_bpm=120
param_loop_num_beats=1
param_repeats=3 -- number of repeats
param_final_rate=1
param_final_level=1
param_monitor=1

const_time_per_refresh=0.1

function init()
  audio.comp_mix(1) -- turn on compressor
  audio.level_adc_cut(1) -- send audio input to softcut input
  audio.level_monitor(1)
  
  -- initialize softcut
  softcut.buffer_clear()
  softcut.enable(1,1)
  softcut.level(1,1)
  softcut.buffer(1,1)
  softcut.loop(1,1)
  softcut.loop_start(1,1)
  softcut.loop_end(1,300)
  softcut.position(1,1)
  softcut.play(1,1)
  softcut.rate_slew_time(1,0)
  softcut.level_slew_time(1,0)
  softcut.pan_slew_time(1,0)
  softcut.rec_level(1,1.0)
  softcut.pre_level(1,0.0)
  softcut.level_input_cut(1,1,1.0)
  softcut.level_input_cut(2,1,1.0)
  softcut.rec(1,1) -- always be recording
  
  timer=metro.init()
  timer.time=const_time_per_refresh
  timer.count=-1
  timer.event=timer_update
  timer:start()
  
  -- parameters
  params:add_control("bpm","bpm",controlspec.new(10,300,"lin",1,90))
  params:add_control("beats","beats",controlspec.new(1,16,"lin",1,1))
  params:add_control("repeat","repeat",controlspec.new(-1,100,"lin",1,3))
  params:add_control("rate","rate",controlspec.new(-4,4,"lin",1,0.1))
  params:add_control("level","level",controlspec.new(0,1,"lin",1,0.1))
  params:add_control("monitor","monitor",{"on","off"})
  
  -- POSITION POLL
  softcut.phase_quant(1,0.025)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end

function update_positions(i,x)
  state_current_position=x
end

function dump(o)
  if type(o)=='table' then
    for k,v in pairs(o) do
      print(k,v)
    end
  end
end

function timer_update()
  -- params=softcut.params()
  -- print(dump(params[1].position.controlspec.warp))
  -- only use timer when state is activated
  if state_activated then
    state_current_time=state_current_time+const_time_per_refresh
    state_tick=math.floor(state_current_time/(60/param_bpm))%2==1
    
    -- get repeat number
    current_repeat=state_repeat_number
    state_repeat_number=math.floor(state_current_time/loop_length())
    if state_repeat_number>current_repeat then
      flag_update_screen=true
    end
    
    -- get beat number
    current_beat_number=state_beat_number
    state_beat_number=1+math.floor(state_current_time/(60/param_bpm/param_loop_num_beats))%param_loop_num_beats
    if state_beat_number~=current_beat_number then
      flag_update_screen=true
    end
    
    print("a",state_current_time,loop_length()*param_repeats,state_tick)
    if param_repeats<10 and state_current_time>=loop_length()*param_repeats then
      deactivate_basic()
    end
  end
  if flag_update_screen then
    redraw()
  end
end

function loop_length()
  return 60/param_bpm/param_loop_num_beats
end

function activate_basic(monitor_mode)
  if state_activated then
    deactivate_basic()
    do return end
  end
  current_position=state_current_position
  prev_position=current_position-loop_length()
  if prev_position<1 then
    prev_position=1
  end
  slew_rate=param_repeats*loop_length()*4
  if slew_rate<0 then
    slew_rate=loop_length()
  end
  print(current_position,prev_position)
  audio.level_monitor(monitor_mode)
  softcut.rec(1,0) -- stop recording
  softcut.level(1,1) -- start playing
  softcut.position(1,prev_position)
  softcut.loop_start(1,prev_position)
  softcut.loop_end(1,current_position)
  softcut.rate_slew_time(1,2*slew_rate)
  softcut.level_slew_time(1,slew_rate)
  softcut.pan_slew_time(1,slew_rate)
  softcut.rate(1,param_final_rate)
  softcut.level(1,param_final_level)
  state_current_time=0
  state_repeat_number=0
  state_activated=true
  flag_update_screen=true
end

function deactivate_basic()
  print("deactivated")
  state_activated=false
  audio.level_monitor(1)
  softcut.rec(1,1) -- start recording
  softcut.position(1,state_current_position+1)
  softcut.loop_start(1,1)
  softcut.loop_end(1,300)
  softcut.rate_slew_time(1,0)
  softcut.level_slew_time(1,0)
  softcut.pan_slew_time(1,0)
  softcut.rate(1,1)
  softcut.level(1,1)
  flag_update_screen=true
end

function enc(n,d)
  if n==1 then
    if state_shift then
    else
      param_repeats=util.clamp(param_repeats+d,1,10)
    end
  elseif n==2 then
    if state_shift then
      param_bpm=util.clamp(param_bpm+d,10,500)
    else
      param_final_level=util.clamp(param_final_level+d/100,0,1)
      if state_activated then
        softcut.level(1,param_final_level)
      end
    end
  elseif n==3 then
    if state_shift then
      param_loop_num_beats=util.clamp(param_loop_num_beats+d,1,16)
    else
      param_final_rate=util.clamp(param_final_rate+d/100,-4,4)
      if state_activated then
        softcut.rate(1,param_final_rate)
      end
    end
  end
  flag_update_screen=true
end

function key(n,z)
  if n==2 and z==1 then
    if state_shift then
      param_final_rate=1
      param_final_level=1
    else
      -- initiate
      activate_basic(1)
    end
  elseif n==3 and z==1 then
    if state_shift then
      -- TODO: randomize final rate/level
    else
      activate_basic(0)
    end
  elseif n==1 then
    state_shift=z==1
  end
  flag_update_screen=true
end

function redraw()
  flag_update_screen=false
  screen.clear()
  shift_amount=0
  if state_shift then
    shift_amount=4
  end
  screen.move(3+shift_amount,8+shift_amount)
  screen.text(param_bpm)
  metro_icon(16+shift_amount,3+shift_amount)
  x=2
  y=20
  h=40
  w=math.floor((120-4*param_repeats)/param_repeats)
  show_repeats=param_repeats
  if state_activated then
    show_repeats=state_repeat_number
  end
  for i=1,show_repeats do
    x=x+2
    screen.move(x,y)
    if i==param_repeats then
      screen.line(x+w*param_final_level,y+h)
    elseif i==1 then
      screen.line(x+w,y+h)
    else
      screen.line(x+w-w*(1-param_final_level)/(param_repeats-1)*(i-1),y+h)
    end
    screen.stroke()
    screen.move(x+w,y)
    r1=(-1*1+4)/8
    r=(-1*param_final_rate+4)/8
    if i==param_repeats then
      screen.line(x+w*r,y+h)
    elseif i==1 then
      screen.line(x+w*r1,y+h)
    else
      if r<r1 then
        screen.line(x+w-w*(r1*r)/(param_repeats-1)*(param_repeats-i+1),y+h)
      elseif r==r1 then
        screen.line(x+w*r,y+h)
      else
        screen.line(x+w-w*(r-r1)/(param_repeats-1)*(param_repeats-i+1),y+h)
      end
    end
    screen.stroke()
    x=x+w+2
  end
  x=34+shift_amount
  y=4+shift_amount
  w=3
  show_beats=param_loop_num_beats
  if state_activated then
    show_beats=current_beat_number
  end
  for i=1,show_beats do
    screen.move(x,y)
    screen.rect(x,y,w,w)
    screen.stroke()
    x=x+w+2
  end
  screen.update()
end

--- Creates icon to show beat relative to interval.
-- Thenk you @itsyourbedtime for creating this for Takt!
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- @tparam tick {boolean}
function metro_icon(x,y)
  screen.move(x+2,y+5)
  screen.line(x+7,y)
  screen.line(x+12,y+5)
  screen.line(x+3,y+5)
  screen.stroke()
  screen.move(x+7,y+3)
  screen.line(state_tick and (x+4) or (x+10),y)
  screen.stroke()
end
