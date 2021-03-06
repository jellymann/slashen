require 'gosu'
require 'opengl'
require 'glfw'

MOVEMENT_SPEED = 0.3
NASTY_SPEED = 0.2
SHWING = 0.01
MULTIKILL_SPEED = 0.003
NASTY_TIME = 1000
ATTACK_MOVE = 0.15
NASTY_STAYS = 0.0001
SHADOW_LENGTH = 500

UP, DOWN, LEFT, RIGHT = 0, 1, 2, 3

OpenGL.load_dll
GLFW.load_dll

include OpenGL
include GLFW

glfwInit

def abs x
  if x < 0
    -x
  else
    x
  end
end

def dot x1, y1, x2, y2
  x1*x2 + y1*y2
end

class MultiKill
  def initialize window, kills, x, y
    @sprite = Gosu::Image.from_text window, "#{kills} kills!", Gosu::default_font_name, 10+(kills*10)
    @time = 1.0
    @x, @y = x, y
  end

  def update dt
    @time -= MULTIKILL_SPEED * dt

    @time <= 0.0
  end

  def draw
    @sprite.draw_rot @x, @y-(1-@time)*40, 1, 0
  end
end

class Slashen < Gosu::Window
  def initialize width = 800, height = 600, fullscreen = false
    super

    @dude = Gosu::Image.new self, "dude.png"
    @light = Gosu::Image.new self, "light.png"
    @light_dead = Gosu::Image.new self, "light_dead.png"
    @dead_dude = Gosu::Image.new self, "dead_dude.png"
    @shwing_sprite = Gosu::Image.load_tiles self, "shwing.png", 72, 72, false
    @debug = Gosu::Image.new self, "debug.png"
    @nasty = Gosu::Image.new self, "nasty.png"
    @dead_nasty = Gosu::Image.new self, "dead_nasty.png"
    @message = Gosu::Image.from_text self, "Press Enter to Kill Things", Gosu::default_font_name, 30
    @time = Gosu::milliseconds
    @speed = Gosu::Image.new self, "speed.png"
    @multikills = []
    start_game
    @playing = false
    @best_score = 0
    @best_kills = 0
    @best_combo = 0
    update_best_image
  end

  def button_up id
    if @playing
      case id
      when Gosu::KbUp, Gosu::KbI, Gosu::GpUp
        @inputs[UP] = false
      when Gosu::KbDown, Gosu::KbK, Gosu::GpDown
        @inputs[DOWN] = false
      when Gosu::KbLeft, Gosu::KbJ, Gosu::GpLeft
        @inputs[LEFT] = false
      when Gosu::KbRight, Gosu::KbL, Gosu::GpRight
        @inputs[RIGHT] = false
      end
    end
  end

  def reset_game
    @nasties = []
    @x, @y = 400, 300
    @vx, @vy = 0, 0
    @dir_x, @dir_y = 1, 0
    @last_nasty = 0
    @shwing = 0.0
    @inputs = Array.new(4, false)
    @me_a = 0.0
    @me_d = 1.0
    @kills = 0
    @score = 0
    @max_combo = 0
    @dead = false
    update_score_image
  end

  def update_score_image
    @score_message = Gosu::Image.from_text self, "#{@kills} kills, #{@score} score, best combo: #{@max_combo}", Gosu.default_font_name, 30
  end

  def update_best_image
    @best_image = Gosu::Image.from_text self, "Best #{@best_kills} kills, #{@best_score} score, #{@best_combo} combo.", Gosu::default_font_name, 30
  end

  def update_you_got
    @you_got = Gosu::Image.from_text self, "You got #{@kills} kills, #{@score} score, #{@max_combo} combo.", Gosu::default_font_name, 30
  end

  def start_game
    reset_game
    @playing = true
  end

  def do_shwing
    @shwing = 1.0
    @shwing_kills = 0
  end

  def button_down id
    if !@playing
      start_game if id == Gosu::KbEnter || id == Gosu::KbReturn || id == Gosu::GpButton12
    else
      case id
      when Gosu::KbUp, Gosu::KbI, Gosu::GpUp
        @inputs[UP] = true
      when Gosu::KbDown, Gosu::KbK, Gosu::GpDown
        @inputs[DOWN] = true
      when Gosu::KbLeft, Gosu::KbJ, Gosu::GpLeft
        @inputs[LEFT] = true
      when Gosu::KbRight, Gosu::KbL, Gosu::GpRight
        @inputs[RIGHT] = true
      when Gosu::KbSpace, Gosu::GpButton12
        do_shwing unless @shwing > 0.0
      end
    end
  end

  def update
    newtime = Gosu::milliseconds
    @delta = newtime - @time
    @time = newtime

    @multikills.delete_if do |mk|
      mk.update @delta
    end

    if @playing
      vx = 0
      vx += 1 if @inputs[RIGHT]
      vx -= 1 if @inputs[LEFT]
      vy = 0
      vy += 1 if @inputs[DOWN]
      vy -= 1 if @inputs[UP]

      if vx != 0 || vy != 0
        @me_a = Math::atan2(vy, vx)
        @me_d = Math::sqrt(vx*vx + vy*vy)
        vx /= @me_d
        vy /= @me_d
        @dir_x = vx
        @dir_y = vy
      end

      if @shwing > 0.0
        @shwing -= SHWING * @delta
        vx += @dir_x * ATTACK_MOVE * @delta
        vy += @dir_y * ATTACK_MOVE * @delta

        if @shwing <= 0.0
          @score += @shwing_kills*2 - 1 unless @shwing_kills == 0
          if @shwing_kills > 1
            @multikills << MultiKill.new(self, @shwing_kills, @x, @y)
          end
          if @shwing_kills > @max_combo
            @max_combo = @shwing_kills
          end
          update_score_image
        end
      end

      @x += vx * @delta * MOVEMENT_SPEED
      @y += vy * @delta * MOVEMENT_SPEED

      if @time - @last_nasty > NASTY_TIME
        @last_nasty = @time
        a = Gosu::random(0,Math::PI*2)
        @nasties << { x: 1000*Math::cos(a), y: 1000*Math::sin(a), a: 0.0 }
      end

      @nasties.delete_if do |nasty|
        if nasty[:death].nil?
          dx = @x - nasty[:x]
          dy = @y - nasty[:y]

          d = Math::sqrt(dx*dx + dy*dy)
          nasty_dot = dot(@dir_x/@me_d,@dir_y/@me_d,-dx/d,-dy/d)
          if d < (36+16) && nasty_dot > 0 && @shwing > 0.0
            @shwing_kills += 1
            nasty[:death] = 1.0
            nasty[:a] = @me_a*180.0/Math::PI + (Gosu::random(-20.0,20.0))
            @kills += 1
            update_score_image
          elsif d < 24+16
            @playing = false
            @dead = true
            if @score > @best_score
              @best_score = @score
            end
            if @kills > @best_kills
              @best_kills = @kills
            end
            if @max_combo > @best_combo
              @best_combo = @max_combo
            end
            update_best_image
            update_you_got
          else
            nasty[:x] += (dx/d) * NASTY_SPEED * @delta
            nasty[:y] += (dy/d) * NASTY_SPEED * @delta

            nasty[:a] = Gosu::angle nasty[:x], nasty[:y], @x, @y
          end

          false
        else
          nasty[:death] -= NASTY_STAYS * @delta

          nasty[:death] < 0.0
        end
      end
    end
  end

  def endpoints_facing x1, y1, x2, y2, r
    a = Gosu::angle x1, y1, x2, y2
    x3 = x1 + Gosu::offset_x(a + 90, r)
    y3 = y1 + Gosu::offset_y(a + 90, r)

    x4 = x1 + Gosu::offset_x(a - 90, r)
    y4 = y1 + Gosu::offset_y(a - 90, r)

    [x3, y3, x4, y4]
  end

  def vector x1, y1, x2, y2
    dy = y2 - y1
    dx = x2 - x1
    [dx, dy]
  end

  def normal x1, y1, x2, y2
    d = Gosu::distance x1, y1, x2, y2
    x, y = vector x1, y1, x2, y2

    [x/d, y/d]
  end

  def draw
    gl do
      #glClearColor 1, 1, 1, 1.0
      glClear GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    end

    @nasties.each do |nasty|
      x = nasty[:x]
      y = nasty[:y]
      dist = Gosu::distance @x, @y, x, y
      depth = 1.0 - (dist / SHADOW_LENGTH)

      a = 1.0 - dist / 500
      a *= 0.5 if @dead
      a = a * 256

      unless nasty[:death]

        bx1, by1, bx2, by2 = endpoints_facing x, y, @x, @y, 16

        nx1, ny1 = normal @x, @y, bx1, by1
        nx2, ny2 = normal @x, @y, bx2, by2

        sx1 = bx1 + nx1 * SHADOW_LENGTH
        sy1 = by1 + ny1 * SHADOW_LENGTH
        sx2 = bx2 + nx2 * SHADOW_LENGTH
        sy2 = by2 + ny2 * SHADOW_LENGTH

        gl depth do
          glDisable GL_DEPTH_TEST
          glEnable GL_BLEND
          glBlendEquationSeparate GL_FUNC_ADD, GL_FUNC_ADD
          glBlendFuncSeparate GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO

          glBegin GL_QUADS
          glColor4f 0, 0, 0, 0.9
          glVertex3f bx1, by1, 0
          glColor4f 0, 0, 0, 0
          glVertex3f sx1, sy1, 0
          glVertex3f sx2, sy2, 0
          glColor4f 0, 0, 0, 0.9
          glVertex3f bx2, by2, 0
          glEnd
        end
      end

      (nasty[:death] ? @dead_nasty : @nasty).draw_rot x, y, depth, nasty[:a], 0.5, 0.5, 1, 1, Gosu::Color.rgba(a, a, a, 255)
    end

    unless @dead
      a = @me_a * 180.0 / Math::PI
      if @shwing > 0.0
        i = (@shwing * @shwing_sprite.size).to_i
        i = 0 if i < 0
        i = @shwing_sprite.size-1 if i >= @shwing_sprite.size
        @shwing_sprite[i].draw_rot @x, @y, 2, a
        #@debug.draw_rot @x, @y, 1, a

        @speed.draw_rot @x, @y, 2, a, 1.0, 0.5
      else
        @dude.draw_rot @x, @y, 1, a
      end
      @light.draw_rot @x, @y, 0, a
    else
      @light_dead.draw_rot @x, @y, 0, 0, 0.5, 0.5, 2, 2
      @dead_dude.draw_rot @x, @y, 0, 0
    end

    unless @playing
      @message.draw 0, 0, 1
      @best_image.draw 0, 40, 1
      if @you_got
        @you_got.draw 0, 80, 1
      end
    else
      @score_message.draw 0, 0, 1
    end

    @multikills.each do |mk|
      mk.draw
    end
  end
end

Slashen.new.show
