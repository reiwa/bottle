pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

config = {
  ball_sizes = { 2, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40 },
  ball_colors = {
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12
  },
  ball_drop_interval = 0.5
}

ui = {
  left_wall = 0 + 16,
  right_wall = 127 - 16,
  bottom_wall = 127,
  game_over_height = 6
}

state = {
  score = 0,
  game_over = false,
}

object = {
  balls = {},
  crane = { x = 64, y = ui.game_over_height + 4 },
  current_ball = { x = 0, y = 0, size = 0 },
  next_ball = { x = 0, y = 0, size = 0 },
  next_next_ball = { x = 0, y = 0, size = 0 }
}

memory = {
  last_ball_dropped_time = 0,
  upgraded_balls = {},
  last_selected_size_index = 0
}

function _init()
  object.current_ball = {
    x = 64,
    y = -40,
    size = select_random_ball_size()
  }
  object.next_ball = {
    x = 127 - 8,
    y = -40,
    size = select_random_ball_size()
  }
  object.next_next_ball = {
    x = 127 - 8,
    y = -40,
    size = select_random_ball_size()
  }
end

function _draw()
  cls()

  draw_ball_line()

  draw_ball(object.crane.x, object.current_ball.y, object.current_ball.size)

  draw_next_ball(127 - 5, object.next_ball.y, object.current_ball.size)

  draw_next_ball(object.next_next_ball.x, object.crane.y, object.next_ball.size)

  foreach(
    object.balls, function(b)
      draw_ball(b.x, b.y, b.size)
    end
  )

  draw_wall()

  draw_score()

  if state.game_over then
    draw_game_over()
  end
end

function draw_ball_line()
  local path = predict_fall_path(object.crane.x, object.crane.y)
  for i = 1, #path do
    pset(path[i].x, path[i].y, 7)
  end
end

function draw_ball(x, y, size)
  local color_index = find_index(config.ball_sizes, size)
  local color = config.ball_colors[color_index] or 8
  circfill(x, y, size, color)
end

function draw_next_ball(x, y, size)
  local color_index = find_index(config.ball_sizes, size)
  local color = config.ball_colors[color_index] or 8
  circfill(x, y, 4, color)
end

function draw_wall()
  rect(ui.left_wall, 0, ui.left_wall, ui.bottom_wall, 7)
  rect(ui.right_wall, 0, ui.right_wall, ui.bottom_wall, 7)
  rect(ui.left_wall, ui.bottom_wall, ui.right_wall, ui.bottom_wall, 7)
end

function draw_game_over()
  local frame_x = 64 - 40
  local frame_y = 64 - 20
  local frame_width = 80
  local frame_height = 12
  rectfill(frame_x, frame_y, frame_x + frame_width, frame_y + frame_height, 9)
  print("game over", frame_x + 4, frame_y + 4, 7)
end

function draw_score()
  print(state.score, 1, 1, 7)
end

function _update()
  if state.game_over then
    return
  end

  foreach(
    object.balls, function(b)
      if b.y <= ui.game_over_height then
        state.game_over = true
      end
    end
  )

  if btn(0) and object.crane.x > ui.left_wall then
    object.crane.x -= 1
  end

  if btn(1) and object.crane.x < ui.right_wall then
    object.crane.x += 1
  end

  local current_time = time()

  local is_active = current_time - memory.last_ball_dropped_time > config.ball_drop_interval

  if btnp(4) and is_active then
    spawn_ball()
    memory.last_ball_dropped_time = current_time
    object.current_ball.size = object.next_ball.size
    object.next_ball.size = object.next_next_ball.size
    object.next_next_ball.size = select_random_ball_size()
  end

  local is_inactive = current_time - memory.last_ball_dropped_time < config.ball_drop_interval

  if is_inactive then
    object.current_ball.y = animate_ball(current_time - memory.last_ball_dropped_time, -8, object.crane.y)
    object.next_ball.y = animate_ball_up(current_time - memory.last_ball_dropped_time, object.crane.y, -40)
    object.next_next_ball.x = animate_ball(current_time - memory.last_ball_dropped_time, 127 + 40, 127 - 8)
  end

  for i = 1, #object.balls do
    local b = object.balls[i]
    local gravity = 0.2
    for j = 1, #object.balls do
      if i ~= j then
        local other = object.balls[j]
        local dist = distance(b.x, b.y, other.x, other.y) - (b.size + other.size)
        if dist < 0 then
          gravity = 0
          break
        end
      end
    end
    b.vy += gravity
    if gravity == 0 then
      b.vy = 0.08
    end
    b.y += b.vy
    b.x += b.vx
    if b.x - b.size <= ui.left_wall then
      b.x = ui.left_wall + b.size
      b.vx = -b.vx * 0.5
    elseif b.x + b.size >= ui.right_wall then
      b.x = ui.right_wall - b.size
      b.vx = -b.vx * 0.5
    end
    if b.y + b.size >= ui.bottom_wall then
      b.y = ui.bottom_wall - b.size
      b.vy = 0.02
    end
    for j = i + 1, #object.balls do
      apply_repulsion(b, object.balls[j])
    end
    check_for_upgrade(b)
  end

  process_size_ups()
end

function select_random_ball_size()
  local size_index
  repeat
    size_index = flr(rnd(3)) + 1
  until size_index != memory.last_selected_size_index
  memory.last_selected_size_index = size_index
  return config.ball_sizes[size_index]
end

function distance(x1, y1, x2, y2)
  return sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

function upgrade_ball(b1, b2)
  local size_index = find_index(config.ball_sizes, b1.size)
  if size_index and size_index < #config.ball_sizes then
    local new_size = config.ball_sizes[size_index + 1]
    local draft_ball = {
      x = (b1.x + b2.x) / 2,
      y = (b1.y + b2.y) / 2,
      vy = 0, vx = 0,
      size = new_size
    }
    add(object.balls, draft_ball)
    del(object.balls, b1)
    del(object.balls, b2)
    state.score += new_size
  end
end

function find_index(list, value)
  for i = 1, #list do
    if list[i] == value then
      return i
    end
  end
  return nil
end

function check_for_upgrade(b)
  for i = 1, #object.balls do
    local other = object.balls[i]
    if b ~= other and b.size == other.size and distance(b.x, b.y, other.x, other.y) < b.size + other.size then
      add(memory.upgraded_balls, { b1 = b, b2 = other })
      return true
    end
  end
  return false
end

function process_size_ups()
  if #memory.upgraded_balls > 0 then
    local pair = memory.upgraded_balls[1]
    upgrade_ball(pair.b1, pair.b2)
    memory.upgraded_balls = {}
  end
end

function check_repulsion(b)
  for j = 1, #object.balls do
    if b ~= object.balls[j] then
      apply_repulsion(b, object.balls[j])
    end
  end
end

function spawn_ball()
  local ball = {
    x = object.crane.x,
    y = object.crane.y,
    vx = 0, vy = 0,
    size = object.current_ball.size
  }

  add(object.balls, ball)
end

function predict_fall_path(x, y)
  local path = {}

  local fall_distance = 8

  local max_steps = 100

  for step = 1, max_steps do
    y += fall_distance
    if y >= ui.bottom_wall then
      break
    end
    add(path, { x = x, y = y })
  end

  return path
end

function animate_ball(elapsed_time, start_y, end_y)
  local total_time = config.ball_drop_interval

  if elapsed_time > 0 and elapsed_time < total_time then
    return start_y + (end_y - start_y) * (elapsed_time / total_time)
  elseif elapsed_time >= total_time then
    return end_y
  else
    return start_y
  end
end

function animate_ball_up(elapsed_time, start_y, end_y)
  local total_time = config.ball_drop_interval

  if elapsed_time > 0 and elapsed_time < total_time then
    return start_y - (start_y - end_y) * (elapsed_time / total_time) -- 上に移動
  elseif elapsed_time >= total_time then
    return end_y
  else
    return start_y
  end
end

function apply_repulsion(b1, b2)
  local dist = distance(b1.x, b1.y, b2.x, b2.y)

  local overlap = (b1.size + b2.size) - dist

  if overlap > 0 then
    local repulsion_strength = 0.3
    if dist < (b1.size + b2.size) / 2 then
      repulsion_strength = 0.5
    end
    local dx = (b1.x - b2.x) / dist * overlap
    local dy = (b1.y - b2.y) / dist * overlap
    b1.x += dx * repulsion_strength
    b1.y += dy * repulsion_strength
    b2.x -= dx * repulsion_strength
    b2.y -= dy * repulsion_strength
    if abs(b1.vx) < 0.1 and abs(b1.vy) < 0.1 then
      b1.vx = 0
      b1.vy = 0
    end
    if abs(b2.vx) < 0.1 and abs(b2.vy) < 0.1 then
      b2.vx = 0
      b2.vy = 0
    end
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
