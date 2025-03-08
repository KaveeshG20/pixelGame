import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:mobilegame/components/checkpoint.dart';
import 'package:mobilegame/components/collision_block.dart';
import 'package:mobilegame/components/custom_hitbox.dart';
import 'package:mobilegame/components/fruit.dart';
import 'package:mobilegame/components/saw.dart';
import 'package:mobilegame/components/utils.dart';
import 'package:mobilegame/pixel_game.dart';

enum PlayerState { idle, running, jumping, falling, hit, appearing, dissapearing }

class Player extends SpriteAnimationGroupComponent with HasGameRef<PixelGame>, KeyboardHandler, CollisionCallbacks{

  String character = ""; 
  //constructor
  Player({position, this.character = 'Ninja Frog'}) : super(position: position);
  


  final double stepTime = 0.05;
  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;
  late final SpriteAnimation dissapearingAnimation;


  final double _gravity = 9.8;
  final double _jumpForce = 460;
  final double _terminalVelocity = 300;


  double horizontalMovement = 0;
  double moveSpeed = 100;
  Vector2 startingPosition = Vector2.zero();
  Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  bool hasJumped = false;
  bool gotHit = false;
  bool reachedCheckpoint = false;
  List<CollisionBlock> collisionBlocks = [];
  CustomHitbox hitbox = CustomHitbox(
    offsetX: 10, 
    offsetY: 4, 
    width: 14, 
    height: 28,
  );

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    debugMode = false;

    startingPosition = Vector2(position.x, position.y);
    add(RectangleHitbox(
      position: Vector2(hitbox.offsetX, hitbox.offsetY),
      size: Vector2(hitbox.width, hitbox.height),
    ));
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if(!gotHit && !reachedCheckpoint){
      _updatePlayerState();
      _updatePlayerMovement(dt);
      _checkHorizontalCollisions();
      _applyGravity(dt);
      _checkVerticalCollisions();
    }
    
    super.update(dt);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalMovement = 0;
    final isLeftKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyA) || keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final isRightKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyD) || keysPressed.contains(LogicalKeyboardKey.arrowRight);
    
    horizontalMovement += isLeftKeyPressed ? -1 : 0;
    horizontalMovement += isRightKeyPressed ? 1 : 0;

    hasJumped = keysPressed.contains(LogicalKeyboardKey.space);
    
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if(!reachedCheckpoint){
        if(other is Fruit) other.collidedWithPlayer();
    if(other is Saw) _respawn();
    if(other is Checkpoint) _reachedCheckpoint();
    }
    
    super.onCollision(intersectionPoints, other);
  }

  
  void _loadAllAnimations() {

      idleAnimation = _spriteAnimation('Idle', 11);
      runningAnimation = _spriteAnimation('Run',12);
      jumpingAnimation = _spriteAnimation('Jump',1);
      fallingAnimation = _spriteAnimation('Fall',1);
      hitAnimation = _spriteAnimation('Hit',7);
      appearingAnimation = _specialSpriteAnimation('Appearing',7);
      dissapearingAnimation = _specialSpriteAnimation('Desappearing',7);

    //all animations
    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      PlayerState.jumping: jumpingAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.hit: hitAnimation,
      PlayerState.appearing: appearingAnimation,
      PlayerState.dissapearing: dissapearingAnimation,
    };

    //current animation
    current = PlayerState.idle;

  }

  SpriteAnimation _spriteAnimation(String state, int amount){
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/$state (32x32).png'), 
      SpriteAnimationData.sequenced(
        amount: amount, 
        stepTime: stepTime, 
        textureSize: Vector2.all(32),
        ),
      );
  }

  SpriteAnimation _specialSpriteAnimation(String state, int amount){
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$state (96x96).png'), 
      SpriteAnimationData.sequenced(
        amount: amount, 
        stepTime: stepTime, 
        textureSize: Vector2.all(96),
        ),
      );
  }

  void _updatePlayerState() {
    PlayerState playerState = PlayerState.idle;


    if(velocity.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (velocity.x > 0 && scale.x < 0){
      flipHorizontallyAroundCenter();
    }

    //set running
    if(velocity.x > 0 || velocity.x < 0) playerState = PlayerState.running;

    //check falling
    if(velocity.y > 0) playerState = PlayerState.falling;
    //jump
    if(velocity.y < 0) playerState = PlayerState.jumping;

    current = playerState;
  }
  
  void _updatePlayerMovement(double dt) {

    if(hasJumped && isOnGround) _playerJump(dt);

    
    
    velocity.x = horizontalMovement * moveSpeed;
    position.x += velocity.x * dt;
  }

  void _playerJump(double dt) {
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    isOnGround = false;
    hasJumped = false;
  }
  
  void _checkHorizontalCollisions() {
    for(final block in collisionBlocks) {
        if(!block.isPlatform){
          if(checkCollision(this, block)){
            if(velocity.x > 0){
              velocity.x = 0;  
              position.x = block.x - hitbox.offsetX  - hitbox.width;
              break;
            }
            if(velocity.x < 0){
              velocity.x = 0;  
              position.x = block.x + block.width + hitbox.width + hitbox.offsetX;
              break;
            }
          }
        }
    }
  }
  
  void _applyGravity(double dt) {
    velocity.y += _gravity;
    velocity.y = velocity.y.clamp(-_jumpForce, _terminalVelocity);
    position.y += velocity.y * dt;
  }
  
  void _checkVerticalCollisions() {
    for(final block in collisionBlocks) {
        if(block.isPlatform){
          if(checkCollision(this, block)){
            if(velocity.y > 0){
              velocity.y = 0;  
              position.y = block.y - hitbox.height - hitbox.offsetY;
              isOnGround = true;
              break;
            }
          }
        }else {
          if(checkCollision(this, block)){
            if(velocity.y > 0){
              velocity.y = 0;  
              position.y = block.y - hitbox.height - hitbox.offsetY;
              isOnGround = true;
              break;
            }
            if(velocity.y < 0){
              velocity.y = 0;  
              position.y = block.y + block.height + height;
            }
          }
        }
    }
  }
  
  void _respawn() {
    const hitDuration = Duration(milliseconds: 350);
    const appearingDuration = Duration(milliseconds: 350);
    const canMoveDuration = Duration(milliseconds: 400);
    gotHit = true;
    current = PlayerState.hit;
    Future.delayed(hitDuration,(){
      scale.x = 1;
        position = startingPosition - Vector2.all(96 - 64);
        current = PlayerState.appearing;
        Future.delayed(appearingDuration,(){
          velocity = Vector2.zero();
          position = startingPosition;
          _updatePlayerState();
          Future.delayed(canMoveDuration, () => gotHit = false);
        });
        
    });
    
  }
  
  void _reachedCheckpoint() {
    reachedCheckpoint = true;

    if(scale.x > 0){
      position = position - Vector2.all(32);
    }else if (scale.x < 0){
      position = position + Vector2(32, -32);
    }
    current = PlayerState.dissapearing;

    const reachedCheckpointDuration = Duration(milliseconds: 350);
    Future.delayed(reachedCheckpointDuration, () {
      reachedCheckpoint = false;
      position = Vector2.all(-640);

      const waitToChangeDuration = Duration(seconds: 3);
      Future.delayed(waitToChangeDuration, () {
        game.loadNextLevel();
      });
    });

  }
  
  
  
  

}