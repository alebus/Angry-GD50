--[[
    GD50
    Angry Birds

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

Level = Class{}

function Level:init()
    
    -- create a new "world" (where physics take place), with no x gravity
    -- and 30 units of Y gravity (for downward force)
    self.world = love.physics.newWorld(0, 300)

    -- if the player has collided with anything yet
    self.playerCollided = false

    -- if the player has already been split into 3
    self.playerSplit = false

    -- bodies we will destroy after the world update cycle; destroying these in the
    -- actual collision callbacks can cause stack overflow and other errors
    self.destroyedBodies = {}

    -- define collision callbacks for our world; the World object expects four,
    -- one for different stages of any given collision
    function beginContact(a, b, coll)
        local types = {}
        types[a:getUserData()] = true
        types[b:getUserData()] = true

        -- if we collided between both the player and an obstacle...
        if types['Obstacle'] and types['Player'] then

            self.playerCollided = true

            -- grab the body that belongs to the player
            local playerFixture = a:getUserData() == 'Player' and a or b
            local obstacleFixture = a:getUserData() == 'Obstacle' and a or b
            
            -- destroy the obstacle if player's combined X/Y velocity is high enough
            local velX, velY = playerFixture:getBody():getLinearVelocity()
            local sumVel = math.abs(velX) + math.abs(velY)

            if sumVel > 20 then
                table.insert(self.destroyedBodies, obstacleFixture:getBody())
            end
        end

        -- if we collided between an obstacle and an alien, as by debris falling...
        if types['Obstacle'] and types['Alien'] then

            -- grab the body that belongs to the player
            local obstacleFixture = a:getUserData() == 'Obstacle' and a or b
            local alienFixture = a:getUserData() == 'Alien' and a or b

            -- destroy the alien if falling debris is falling fast enough
            local velX, velY = obstacleFixture:getBody():getLinearVelocity()
            local sumVel = math.abs(velX) + math.abs(velY)

            if sumVel > 20 then
                table.insert(self.destroyedBodies, alienFixture:getBody())
            end
        end

        -- if we collided between the player and the alien...
        if types['Player'] and types['Alien'] then

            self.playerCollided = true

            -- grab the bodies that belong to the player and alien
            local playerFixture = a:getUserData() == 'Player' and a or b
            local alienFixture = a:getUserData() == 'Alien' and a or b

            -- destroy the alien if player is traveling fast enough
            local velX, velY = playerFixture:getBody():getLinearVelocity()
            local sumVel = math.abs(velX) + math.abs(velY)

            if sumVel > 20 then
                table.insert(self.destroyedBodies, alienFixture:getBody())
            end
        end

        -- if we hit the ground, play a bounce sound
        if types['Player'] and types['Ground'] then
            self.playerCollided = true
            gSounds['bounce']:stop()
            gSounds['bounce']:play()
        end
    end

    -- the remaining three functions here are sample definitions, but we are not
    -- implementing any functionality with them in this demo; use-case specific
    -- http://www.iforce2d.net/b2dtut/collision-anatomy
    function endContact(a, b, coll)
        
    end

    function preSolve(a, b, coll)

    end

    function postSolve(a, b, coll, normalImpulse, tangentImpulse)

    end

    -- register just-defined functions as collision callbacks for world
    self.world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    -- shows alien before being launched and its trajectory arrow
    self.launchMarker = AlienLaunchMarker(self.world)

    -- aliens in our scene
    self.aliens = {}

    -- obstacles guarding aliens that we can destroy
    self.obstacles = {}

    -- simple edge shape to represent collision for ground
    self.edgeShape = love.physics.newEdgeShape(0, 0, VIRTUAL_WIDTH * 10, 0)

    -- spawn an alien to try and destroy
    table.insert(self.aliens, Alien(self.world, 'square', VIRTUAL_WIDTH - 80, VIRTUAL_HEIGHT - TILE_SIZE - ALIEN_SIZE / 2, 'Alien'))

    -- spawn a few obstacles
    table.insert(self.obstacles, Obstacle(self.world, 'vertical',
        VIRTUAL_WIDTH - 120, VIRTUAL_HEIGHT - 35 - 110 / 2))
    table.insert(self.obstacles, Obstacle(self.world, 'vertical',
        VIRTUAL_WIDTH - 35, VIRTUAL_HEIGHT - 35 - 110 / 2))
    table.insert(self.obstacles, Obstacle(self.world, 'horizontal',
        VIRTUAL_WIDTH - 80, VIRTUAL_HEIGHT - 35 - 110 - 35 / 2))

    -- ground data
    self.groundBody = love.physics.newBody(self.world, -VIRTUAL_WIDTH, VIRTUAL_HEIGHT - 35, 'static')
    self.groundFixture = love.physics.newFixture(self.groundBody, self.edgeShape)
    self.groundFixture:setFriction(0.5)
    self.groundFixture:setUserData('Ground')

    -- background graphics
    self.background = Background()
end

function Level:update(dt)
    
    -- update launch marker, which shows trajectory
    self.launchMarker:update(dt)

    -- Box2D world update code; resolves collisions and processes callbacks
    self.world:update(dt)

    -- destroy all bodies we calculated to destroy during the update call
    for k, body in pairs(self.destroyedBodies) do
        if not body:isDestroyed() then 
            body:destroy()
        end
    end

   
    -- debug
    --print("self.playerCollided: ", self.playerCollided)

    -- reset destroyed bodies to empty table for next update phase
    self.destroyedBodies = {}

    -- remove all destroyed obstacles from level
    for i = #self.obstacles, 1, -1 do
        if self.obstacles[i].body:isDestroyed() then
            table.remove(self.obstacles, i)

            -- play random wood sound effect
            local soundNum = math.random(5)
            gSounds['break' .. tostring(soundNum)]:stop()
            gSounds['break' .. tostring(soundNum)]:play()
        end
    end

    -- remove all destroyed aliens from level
    for i = #self.aliens, 1, -1 do
        if self.aliens[i].body:isDestroyed() then
            table.remove(self.aliens, i)
            gSounds['kill']:stop()
            gSounds['kill']:play()
        end
    end

    
    -- replace launch marker if original alien stopped moving
    if self.launchMarker.launched then
        local xPos, yPos = self.launchMarker.alien.body:getPosition()
        local xVel, yVel = self.launchMarker.alien.body:getLinearVelocity()


        


        -- if we fired our alien to the left or it's almost done rolling, respawn
        if xPos < 0 or (math.abs(xVel) + math.abs(yVel) < 1.5) or xPos > VIRTUAL_WIDTH then
            print("alien1 has stopped moving")
            -- if there are 2 more to check, wait for them as well
            if self.playerSplit then
                
                local xPos2, yPos2 = self.alien2.body:getPosition()
                local xVel2, yVel2 = self.alien2.body:getLinearVelocity()
            
                local xPos3, yPos3 = self.alien3.body:getPosition()
                local xVel3, yVel3 = self.alien3.body:getLinearVelocity()
            
                print(xPos3)
                print(xPos2)
        
                -- I added > VIRTUAL_WIDTH to fix a bug where it would not end if alien2 or alien3 flew off the screen to the right

                if (xPos2 < 0 or xPos2 > VIRTUAL_WIDTH or (math.abs(xVel2) + math.abs(yVel2) < 1.5)) 
                    and (xPos3 < 0 or xPos2 > VIRTUAL_WIDTH or (math.abs(xVel3) + math.abs(yVel3) < 1.5)) then
                
                    -- this always happens, post-split or not
                    self.launchMarker.alien.body:destroy()
                    self.launchMarker = AlienLaunchMarker(self.world)

                    print("alien 2 and 3 have stopped moving")
                    self.alien2.body:destroy()
                    self.alien3.body:destroy()
            
                    for i = #self.aliens, 1, -1 do
                        if self.aliens[i].body:isDestroyed() then
                            table.remove(self.aliens, i)
                        end
                    end
                
                    self.playerSplit = false

                        -- re-initialize level if we have no more enemy aliens
                        local enemyAlienLeft = false
                        for k, alien in pairs(self.aliens) do
                        
                            if alien.type == 'square' then
                                enemyAlienLeft = true
                            end
                        
                        end
                
                        if not enemyAlienLeft then
                      
                            gStateMachine:change('start')
                        end
                end
            else -- this is all the code for if there is only one alien

                self.launchMarker.alien.body:destroy()
                self.launchMarker = AlienLaunchMarker(self.world)

                
                -- re-initialize level if we have no more enemy aliens
                local enemyAlienLeft = false
                for k, alien in pairs(self.aliens) do
                
                    if alien.type == 'square' then
                        enemyAlienLeft = true
                    end
                
                end
        
                if not enemyAlienLeft then
                    gStateMachine:change('start')
                end
            
            end
        end
    end
end

function Level:render()
    
    -- render ground tiles across full scrollable width of the screen
    for x = -VIRTUAL_WIDTH, VIRTUAL_WIDTH * 2, 35 do
        love.graphics.draw(gTextures['tiles'], gFrames['tiles'][12], x, VIRTUAL_HEIGHT - 35)
    end

    self.launchMarker:render()

    for k, alien in pairs(self.aliens) do
        alien:render()
    end


    for k, obstacle in pairs(self.obstacles) do
        obstacle:render()
    end

    -- render instruction text if we haven't launched 
    if not self.launchMarker.launched then
        love.graphics.setFont(gFonts['medium'])
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf('Click and drag circular alien to shoot!',
            0, 64, VIRTUAL_WIDTH, 'center')
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- render victory text if all aliens are dead
    -- check to see if there any square ones left - if not, then is victory
    local enemyAlienLeft = false
    for k, alien in pairs(self.aliens) do
    
        if alien.type == 'square' then
            enemyAlienLeft = true
        end
    
    end

    if not enemyAlienLeft then
        love.graphics.setFont(gFonts['huge'])
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf('VICTORY', 0, VIRTUAL_HEIGHT / 2 - 32, VIRTUAL_WIDTH, 'center')
        love.graphics.setColor(1, 1, 1, 1)
    end


end



function Level:spawnPlayers()

    
    if not self.playerSplit and self.launchMarker.launched then

        
        local origX = self.launchMarker.alien.body:getX( )
        local origY = self.launchMarker.alien.body:getY( )


        self.alien2 = Alien(self.world, 'round', origX, origY, 'Player')
        self.alien2.fixture:setRestitution(0.4)
        self.alien2.body:setAngularDamping(1)
        self.alien2.body:setLinearVelocity((self.launchMarker.baseX - self.launchMarker.shiftedX) * 10, 
            ( 5 + self.launchMarker.baseY - self.launchMarker.shiftedY) * 10)

        
        self.alien3 = Alien(self.world, 'round', origX, origY, 'Player')
        self.alien3.fixture:setRestitution(0.4)
        self.alien3.body:setAngularDamping(1)
        self.alien3.body:setLinearVelocity((self.launchMarker.baseX - self.launchMarker.shiftedX) * 10, 
            ( -5 + self.launchMarker.baseY - self.launchMarker.shiftedY) * 10)

        
        table.insert(self.aliens, self.alien2)
        table.insert(self.aliens, self.alien3)


        self.playerSplit = true
        print("playerSplit: ", self.playerSplit)
    end


end


function Level:resetPlayerSplit()

    self.playerSplit = false

end