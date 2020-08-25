-- clcks v0.1
-- tempo-locked repeat
--
-- llllllll.co/t/clcks
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

state={
  activated=false,
  time=0,
  repeats=0,
  beat=0,
  position=0,
  shift=false,
  tick=false,
  update_screen=false,
}

function init()
  audio.level_adc_cut(1) -- send audio input to softcut input
  audio.level_monitor(1)
  
  -- initialize softcut
  softcut.buffer_clear()
  for i=1,2 do
    softcut.enable(i,1)
    softcut.level(i,1)
    softcut.buffer(i,i) -- l&r use buffers 1&2
    softcut.loop(i,1)
    softcut.loop_start(i,1)
    softcut.loop_end(i,300)
    softcut.position(i,1)
    softcut.play(i,1)
    softcut.rate_slew_time(i,0)
    softcut.level_slew_time(i,0)
    softcut.pan(i,(i-1)*2-1) --stereo
    softcut.rec_level(i,1.0)
    softcut.pre_level(i,0.0)
    softcut.level_input_cut(i,i,1.0)
    softcut.rec(i,1) -- always be recording
  end
  
  timer=metro.init()
  timer.time=60/params:get("clock_tempo")/16
  timer.count=-1
  timer.event=timer_update
  timer:start()
  
  -- parameters
  params:set_action("clock_tempo",update_clock)
  params:add_control("beats","beats",controlspec.new(1,16,"lin",1,1))
  params:add_control("repeat","repeat",controlspec.new(1,10,"lin",1,3))
  params:add_control("rate","rate",controlspec.new(0,4,"lin",1,0.1))
  params:set_action("rate",update_rate)
  params:add_control("level","level",controlspec.new(0,1,"lin",1,0.1))
  params:set_action("level",update_level)
  params:add_control("randomizer","randomizer",{"on","off"})
  
  -- position poll
  softcut.phase_quant(1,0.025) -- monitor one position to get both
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end

function update_clock(x)
  timer.time=60/x/16
end

function update_level(x)
  if state.activated then
    for i=1,2 do
      softcut.level(i,x)
    end
  end
end

function update_rate(x)
  if state.activated then
    for i=1,2 do
      softcut.rate(i,x)
    end
  end
end

function update_positions(i,x)
  state.position=x
end

function timer_update()
  if state.activated then
    state.time=state.time+const_time_per_refresh
    state.tick=round(state.time/(60/params:get("clock_tempo")))%2==1
    
    -- get repeat number
    current_repeat=state.repeats
    state.repeats=math.floor(state.time/loop_length())
    if state.repeats>current_repeat then
      state.update_screen=true
    end
    
    -- get beat number
    current_beat_number=state.beat
    state.beat=1+math.floor(state.time/(loop_length()))%params:get("beats")
    if state.beat~=current_beat_number then
      state.update_screen=true
    end
    
    if params:get("repeat")<10 and state.time>=loop_length()*params:get("repeat") then
      deactivate_basic()
    end
  end
  if state.update_screen then
    redraw()
  end
end

function loop_length()
  return 60/params:get("clock_tempo")/params:get("beats")
end

function activate_basic(monitor_mode)
  if state.activated then
    deactivate_basic()
    do return end
  end
  current_position=state.position
  prev_position=current_position-loop_length()
  if prev_position<1 then
    prev_position=1
  end
  slew_rate=params:get("repeat")*loop_length()*4
  if slew_rate<0 then
    slew_rate=loop_length()
  end
  audio.level_monitor(monitor_mode)
  for i=1,2 do
    softcut.rec(i,0) -- stop recording
    softcut.level(i,1) -- start playing
    softcut.position(i,prev_position)
    softcut.loop_start(i,prev_position)
    softcut.loop_end(i,current_position)
    softcut.rate_slew_time(1,2*slew_rate)
    softcut.level_slew_time(i,slew_rate)
    softcut.rate(i,params:get("rate"))
    softcut.level(i,params:get("level"))
  end
  state.time=0
  state.repeats=0
  state.activated=true
  state.update_screen=true
end

function deactivate_basic()
  print("deactivated")
  state.activated=false
  audio.level_monitor(1)
  for i=1,2 do
    softcut.rec(i,1) -- start recording
    softcut.position(i,state.position+1)
    softcut.loop_start(i,1)
    softcut.loop_end(i,300)
    softcut.rate_slew_time(i,0)
    softcut.level_slew_time(i,0)
    softcut.rate(i,1)
    softcut.level(i,1)
  end
  state.update_screen=true
end

function randomizer()
  clock.sleep(math.random(0,10))
  if params:get("randomizer")=="off" then
    do return end
  end
  params:set("level",math.random(0,1))
  params:set("rate",math.random(-4,4))
  params:set("repeat",round(math.random(1,5)))
  params:set("beats",round(math.random(1,8)))
  monitor_mode=round(math.random())
  state.update_screen=true
  activate_basic(monitor_mode)
  clock.run(randomizer)
end

function enc(n,d)
  if n==1 then
    if state.shift then
    else
      params:set("repeat",util.clamp(params:get("repeat")+d,1,10))
    end
  elseif n==2 then
    if state.shift then
      params:set("clock_tempo",util.clamp(params:get("clock_tempo")+d,10,500))
    else
      params:set("level",util.clamp(params:get("level")+d/100,0,1))
    end
  elseif n==3 then
    if state.shift then
      params:set("beats",util.clamp(params:get("beats")+d,1,16))
    else
      -- turning ccw sets to reverse
      -- turning cw sets to forward
      params:set("rate",d*util.clamp(params:get("rate")+d/100,0,4))
    end
  end
  state.update_screen=true
end

function key(n,z)
  if n==2 and z==1 then
    if state.shift then
      -- reset final parameters
      params:set("randomizer","off")
      params:set("rate",1)
      params:set("level",1)
    else
      -- initiate with monitor mode
      activate_basic(1)
    end
  elseif n==3 and z==1 then
    if state.shift then
      -- randomize chop
      params:set("randomizer","on")
      clock.run(randomizer)
    else
      -- initate without monitor mode
      activate_basic(0)
    end
  elseif n==1 then
    state.shift=z==1
  end
  state.update_screen=true
end

function redraw()
  state.update_screen=false
  screen.clear()
  shift_amount=0
  if state.shift then
    shift_amount=4
  end
  
  -- draw bpm
  screen.move(3+shift_amount,8+shift_amount)
  screen.text(params:get("clock_tempo"))
  metro_icon(16+shift_amount,3+shift_amount)
  
  -- draw beat subidivision boxes
  x=34+shift_amount
  y=4+shift_amount
  w=3
  show_beats=params:get("beats")
  if state.activated then
    show_beats=current_beat_number
  end
  for i=1,show_beats do
    screen.move(x,y)
    screen.rect(x,y,w,w)
    screen.stroke()
    x=x+w+2
  end
  
  -- draw clocks
  x=2
  y=20
  h=40
  w=round(120/params:get("repeat"))
  show_repeats=params:get("repeat")
  if state.activated then
    show_repeats=state.repeats
  end
  short_hand_angle=180*math.abs(params:get("rate"))/4+90
  
  for i=1,show_repeats do
    r=(w/2)*(params:get("repeat")-i)/(params:get("repeat")-1)
    r=r+(w/2)*(1-(params:get("repeat")-i)/(params:get("repeat")-1))*params:get("level")
    if i==1 then
      r=(w/2)
    elseif i==state.repeats then
      r=(w/2)*params:get("level")
    end
    r=r+2
    
    -- draw "circle"
    center={x+w/2,y+w/2}
    screen.move(center[1],y)
    screen.curve(center[1],y+h,center[1]-r,y,center[1]-r,y+h)
    screen.stroke()
    screen.move(center[1],y)
    screen.curve(center[1],y+h,center[1]+r,y,center[1]+r,y+h)
    screen.stroke()
    
    -- short hand indicates absolute rate
    screen.arc(center[1],center[2],r/2,short_hand_angle,short_hand_angle)
    
    -- long hand indicates direction of rate
    angle=(i-1)*36
    if params:get("rate")<0 then
      angle=360-angle
    end
    screen.arc(center[1],center[2],r,angle,angle)
    
    -- update x position
    x=x+w -- TODO: try using r instead
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
  screen.line(state.tick and (x+4) or (x+10),y)
  screen.stroke()
end

function round(num)
  under=math.floor(num)
  upper=math.floor(num)+1
  underV=-(under-num)
  upperV=upper-num
  if (upperV>underV) then
    return under
  else
    return upper
  end
end
