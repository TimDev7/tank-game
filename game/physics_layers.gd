class_name PhysicsLayers
extends RefCounted
## Единая таблица слоёв коллизий для арены, танков и пуль.
## Значения — номера слоёв (1..32) для set_collision_layer_value / set_collision_mask_value.
## Те же имена нужно задать в Project Settings -> Layer Names -> 2D Physics (через редактор).
##
## Пример для пули:  layer = BULLET, mask = WALL + TANK
##   bullet.set_collision_layer_value(PhysicsLayers.BULLET, true)
##   bullet.set_collision_mask_value(PhysicsLayers.WALL, true)

const WALL := 1
const TANK := 2
const BULLET := 3
const CRATE := 4
