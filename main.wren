import "graphics" for Canvas, Color, ImageData
import "audio" for AudioEngine
import "input" for Keyboard
import "random" for Random

var CANVAS_WIDTH = 400
var CANVAS_HEIGHT = 300
var MIN_ENEMIES = 4
var MAX_ENEMIES = 12
var RANDOM = Random.new()
var MESSAGES = [
  "Feel my wrath!",
  "GRRRR!!!!",
  "Prepare to meet your doom!",
  "I'll give you a recovery code you'll never forget!",
  "I will rain down upon you like an ungodly firestorm!",
  "Cry havoc and let slip the dogs of war!",
  "Why did you delete the authenticator app?!?!"
]

class Sfx {
  static init() {
    __sounds = {}
  }

  static load(group, count) {
    __sounds[group] = count
    
    for (i in 1..count) {
      var id = "%(group)%(i)"
      AudioEngine.load(id, "sounds/%(id).ogg")
    }
  }

  static playRandom(group) {
    AudioEngine.play("%(group)%(RANDOM.int(1, __sounds[group] + 1))")
  }
}

class Pew {
  construct init(x, y) {
    _x = x
    _y = y
    _pic = ImageData.loadFromFile("images/fish.png")
    _used = false
  }

  use() { _used = true }

  update() {
    if (_y < CANVAS_HEIGHT) _y = _y + 1
  }

  draw() {
    _pic.draw(_x, _y)
  }

  isInRangeOf(enemy) {
    return !_used && enemy.x >= _x - enemy.w && enemy.x <= _x + 32 && enemy.y >= _y - enemy.h && enemy.y <= _y + 32
  }

  visible { _y < CANVAS_HEIGHT }
}

class Enemy {
  construct init(x) {
    _w = 32
    _h = 32
    _x = x
    _y = CANVAS_HEIGHT - _h
    _moves = 0
    _direction = getRandomDirection()
    _speed = 1
    _directionChangeDelay = 60 + RANDOM.int(30)
    _dying = false
    _alive = true
    _deathCountdown = 60
    _picAlive = ImageData.loadFromFile("images/enemy.png")
    _picDead = ImageData.loadFromFile("images/enemy-dead.png")
  }

  w { _w }

  h { _h }

  x { _x }

  y { _y }

  alive { _alive }

  dying { _dying }
  
  update() {
    if (_deathCountdown == 0) {
      _alive = false
    }
    
    if (_dying && _alive) {
      _deathCountdown = _deathCountdown - 1
    }

    if (_dying || !_alive) {
      return
    }

    // change direction after 60 moves
    if (_moves == _directionChangeDelay) {
      _moves = 0
      _direction = getRandomDirection()
    } else {
      _moves = _moves + 1
      _x = _x + _direction * _speed

      // turn around when at the edge
      if (_x == 0 && _direction == -1) {
        _direction = 1
      } else if (_x == CANVAS_WIDTH - _w && _direction == 1) {
        _direction = -1
      }
    }
  }

  getRandomDirection() {
     return (-1).pow(RANDOM.int(2))
  }

  draw() {
    if (_dying) {
      _picDead.draw(_x, _y)
    } else {
      _picAlive.draw(_x, _y)
    }
  }

  kill() {
    if (!_dying) {
      Sfx.playRandom("ow")
      _dying = true
    }
  }
}

class Player {
  construct init() {
    _x = CANVAS_WIDTH / 2 - 16
    _y = CANVAS_HEIGHT / 2 - 16
    _pic = ImageData.loadFromFile("images/walrus.png")
    _pews = []
    _shooting = false
    _text = ""
    _alive = true
  }

  alive=(alive) { _alive = alive }
  
  pews { _pews }

  update() {
    if (!_alive) return

    if (Keyboard.isKeyDown("left")) {
      _x = _x - 1 
    } 

    if (Keyboard.isKeyDown("right")) {
      _x = _x + 1 
    }
 
    if (Keyboard.isKeyDown("space") && !_shooting) {
      _shooting = true
      shoot()
    }
    if (!Keyboard.isKeyDown("space")) {
      _shooting = false
    }

    var visiblePews = []

    for (pew in _pews) {
      pew.update()
      if (pew.visible) visiblePews.add(pew)
    }

    _pews = visiblePews
  }

  shoot() {
    var pew = Pew.init(_x, _y + 20)
    _pews.add(pew)
    _text = MESSAGES[RANDOM.int(MESSAGES.count)]
      Sfx.playRandom("grunt")
  }

  draw() {
    _pic.draw(_x, _y)
    for (pew in _pews) {
      pew.draw()
    }
    Canvas.print(_text, 1, 1, Color.black)
  }
  
}

class Game {
  static init() {
    AudioEngine.load("theme", "music/theme.ogg")
    AudioEngine.load("gameover", "music/gameover.ogg")
    
    Sfx.init()
    Sfx.load("grunt", 4)
    Sfx.load("iforgot", 9)
    Sfx.load("ow", 10)
    
    Canvas.resize(CANVAS_WIDTH, CANVAS_HEIGHT)

    __started = false
    // start()
  }

  static start() {
    __started = true
    __gameOver = false
    __music = AudioEngine.play("theme")
    __music.loop = true
    // music.volume = 0.5 // doesn't work
    
    __player = Player.init()
    __enemies = []
    __gameOver = false

    for (i in 1..RANDOM.int(MIN_ENEMIES, MAX_ENEMIES)) {
      __enemies.add(Enemy.init(RANDOM.int(CANVAS_WIDTH - 32)))
    }

    __sfxDelay = 0
  }

  static update() {
    if (!__started) {
      if(Keyboard.isKeyDown("Return")) start()
      return
    }

    if (!__gameOver) {
      if (__sfxDelay == 0) {
        __sfxDelay = 300 + RANDOM.int(30)
        Sfx.playRandom("iforgot")
      } else {
        __sfxDelay = __sfxDelay - 1
      }
    }

    if (__gameOver && Keyboard.isKeyDown("Return")) {
      start()
      return
    }


    __player.update()
    var aliveEnemies = []
    for (enemy in __enemies) {
      if (enemy.alive) {
        enemy.update()
        aliveEnemies.add(enemy)
      }
    }

    __enemies = aliveEnemies

    for (pew in __player.pews) {
      for (enemy in __enemies) {
        if (pew.isInRangeOf(enemy) && !enemy.dying) {
          pew.use()
          enemy.kill()
        }
      }
    }

    if (__enemies.count == 0 && !__gameOver) {
      __gameOver = true
      __player.alive = false
      __music.stop()
      AudioEngine.play("gameover")
    }

  }

  static drawBg() {
    var bg = ImageData.loadFromFile("images/bg.png")
    var size = 64
    var h = 0
    
    while (h < CANVAS_HEIGHT) {
      var w = 0
      while (w < CANVAS_WIDTH) {
        bg.draw(w, h)
        w = w + size
      }
      h = h + size
    }
  }

  static draw(alpha) {
    Canvas.cls()

    if (!__started) {
      Canvas.print("WALRUS SIMULATOR", 135, 150, Color.white)
      Canvas.print("> Press Enter to play <", 105, 170, Color.rgb(155, 155, 155))
    } else if (__gameOver) {
      Canvas.rectfill(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT, Color.black)
      Canvas.print("GAME OVER!", 155, 150, Color.white)
      Canvas.print("> Press Enter to play again <", 80, 170, Color.rgb(155, 155, 155))
    } else {
      drawBg()
      __player.draw()
      for (enemy in __enemies) {
        enemy.draw()
      }
    }
  }

}