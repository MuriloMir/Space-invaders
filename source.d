// This software is a space invaders game.

// import the tools we need
import arsd.image: loadImageFromFile;
import arsd.simpleaudio : AudioOutputThread;
import arsd.simpledisplay : Image, Key, KeyEvent, MemoryImage, MouseButton, MouseEvent, MouseEventType, Point, Rectangle, ScreenPainter, SimpleWindow,
                            Sprite;

// in case you are on Windows
version (Windows)
{
    // these 2 lines will simply stop the terminal from popping-up
    pragma(linkerDirective, "/subsystem:windows");
    pragma(linkerDirective, "/entry:mainCRTStartup");
}

// a struct to represent each alien
struct Alien
{
    // this is the alien's life
    int life;
    // this is the alien's position
    Point position;
    // these will be the costumes of the alien when it is alive and when it is dead
    Sprite alive, dead;
    // this boolean will tell if the alien has been destroyed
    bool destroyed;
}

// start the software
void main()
{
    // create the GUI window
    SimpleWindow window = new SimpleWindow(1000, 400, "Space Invaders");
    // create and start the audio thread
    AudioOutputThread music = AudioOutputThread(true);
    // load the memory images
    MemoryImage memBackground = loadImageFromFile("images/background.png"), memShipNormal = loadImageFromFile("images/ship normal.png"),
                memShipTurbo = loadImageFromFile("images/ship turbo.png"), memPrimFire = loadImageFromFile("images/primary fire.png"),
                memSuperFire = loadImageFromFile("images/super fire.png"), memDefeat = loadImageFromFile("images/defeat.png"),
                memEnd = loadImageFromFile("images/end.png");
    // create the actual images
    Image background = Image.fromMemoryImage(memBackground), defeat = Image.fromMemoryImage(memDefeat), end = Image.fromMemoryImage(memEnd);
    // create the sprites
    Sprite shipNormal = new Sprite(window, Image.fromMemoryImage(memShipNormal, true)),
           shipTurbo = new Sprite(window, Image.fromMemoryImage(memShipTurbo, true)),
           primFire = new Sprite(window, Image.fromMemoryImage(memPrimFire, true)),
           superFire = new Sprite(window, Image.fromMemoryImage(memSuperFire, true)), ship = shipNormal;
    // create the booleans to keep track of the current state of the player and the game
    bool superShotFired, superShotOver, upgradeEarned, won, lost;
    // 'backgroundHeight' controls the position of the background, which rolls down as you play, and 'movingSpeed' controls the speed of the ship
    int backgroundHeight = -2400, movingSpeed = 1;
    // 'shipPosition' will keep track of the ship's position and 'superShotPosition' will keep track of the super shot position (in case you fire it)
    Point shipPosition = Point(400, 300), superShotPosition;
    // create an array where we will place the current position of every single primary shot you fire (not counting the super shot)
    Point[] shotsPositions;
    // create an array full of aliens that will attack you, the struct 'Alien' is defined above
    Alien[6] aliens;
    // create rectangles for the aliens, for your ship, for the super shot and for the normal shots, because the computer only understands rectangles
    Rectangle alienRect, shipRect, superShotRect, shotRect;
    // create the array with the names of the image files of them alive and then the array with the image files of them dead
    string[6] imgNamesAlive = ["images/alien0alive.png", "images/alien1alive.png", "images/alien2alive.png", "images/alien3alive.png",
                               "images/alien4alive.png", "images/alien5alive.png"],
              imgNamesDead = ["images/alien0dead.png", "images/alien1dead.png", "images/alien2dead.png", "images/alien3dead.png",
                              "images/alien4dead.png", "images/alien5dead.png"];
	// then we get the start points of each alien
    Point[6] startPoints = [Point(100, -120), Point(600, -300), Point(200, -500), Point(800, -700), Point(250, -900), Point(400, -1750)];
	// this variable will store the alien's life in the loop below
    int life;

	// use a loop to create each of the 6 aliens
    foreach (i; 0 .. 6)
    {
        // load the memory image
        MemoryImage memAlive = loadImageFromFile(imgNamesAlive[i]), memDead = loadImageFromFile(imgNamesDead[i]);
        // turn it into a sprite
        Sprite imgAlive = new Sprite(window, Image.fromMemoryImage(memAlive, true)), imgDead = new Sprite(window, Image.fromMemoryImage(memDead, true));
        // define the alien's struct, the variable life is incremented by 5 at each iteration, so that each alien is stronger than its predecessor
        aliens[i] = Alien(life += 5, startPoints[i], imgAlive, imgDead);
    }

    // start playing the background music
    music.playOgg("sounds/background.ogg", true);
    // hide the cursor because we don't want it on top of the ship
    window.hideCursor();

    // start the window's event loop
    window.eventLoop(30,
    {
        // create the screen painter
        ScreenPainter painter = window.draw();

        // if you've won
        if (won)
            // draw the end image
            painter.drawImage(Point(0, 0), end);
        // if you've lost
        else if (lost)
            // draw the defeat image
            painter.drawImage(Point(0, 0), defeat);
        // if you are still playing, then we draw everything on the screen
        else
        {
            // draw the background, it's a very big image
            painter.drawImage(Point(0, backgroundHeight), background);

            // start a loop to draw all shots (primary fire)
            foreach (i; 0 .. shotsPositions.length)
            {
                // draw the fire's sprite
                primFire.drawAt(painter, shotsPositions[i]);
                // update the fire's position for the next iteration (taking into account the player's speed)
                shotsPositions[i].y -= 15 + movingSpeed;
            }

            // if you have fired the super shot and it still hasn't gone over the window's edge
            if (superShotFired && !superShotOver)
            {
                // draw the super shot
                superFire.drawAt(painter, superShotPosition);
                // update it's position
                superShotPosition.y -= (15 + movingSpeed);
                // update the rectangle around it
                superShotRect = Rectangle(superShotPosition.x, superShotPosition.y, superShotPosition.x + superFire.width(),
                                          superShotPosition.y + superFire.height());
                // check if it has already disappeared from the window, in which case you set this boolean to true
                superShotOver = superShotPosition.y + superFire.height() < 0;
            }

            // start a loop to draw each alien on the window
            foreach (i; 0 .. 6)
            {
                // if this alien has been destroyed
                if (aliens[i].destroyed)
                    // draw it with the dead costume
                    aliens[i].dead.drawAt(painter, aliens[i].position);
                // if it is still alive
                else
                {
                    // draw it with the living costume
                    aliens[i].alive.drawAt(painter, aliens[i].position);

                    // if it's still alive and it has totally passed by your ship
                    if (aliens[i].position.y > 400)
                        // set this boolean to true, you lose the game
                        lost = true;
                }

                // update the alien's position based on your current speed (your speed changes when you use the turbo)
                aliens[i].position.y += movingSpeed;
            }

            // draw your ship
            ship.drawAt(painter, shipPosition);
        }

        // if you're still playing
        if (!(won || lost))
        {
            // update the background's height
            backgroundHeight += movingSpeed;

            // if you've finally reached the end of the game
            if (backgroundHeight > -5)
                // set this boolean to true, you've won
                won = true;
            // if you have not reached the end yet, then we damage the aliens (if you've shot them) and check if you've crashed into them
            else
                // start a loop to check, for each alien, if you have hit it or crashed into it
                foreach (i; 0 .. 6)
                {
                    // if the alien is still alive and it hasn't yet totally passed by you
                    if (!aliens[i].destroyed && aliens[i].position.y + aliens[i].alive.height() > 0 && aliens[i].position.y < 400)
                    {
                        // define a rectangle around the alien and one around your ship, because the computer only understands rectangles
                        alienRect = Rectangle(aliens[i].position.x, aliens[i].position.y, aliens[i].position.x + aliens[i].alive.width(),
                                              aliens[i].position.y + aliens[i].alive.height());
                        shipRect = Rectangle(shipPosition.x, shipPosition.y, shipPosition.x + ship.width(), shipPosition.y + ship.height());

                        // if you've used the super shot and it still hasn't disappeared from the window
                        if (superShotFired && !superShotOver)
                            // if the center of the super shot is inside the alien's rectangle then it deeply intersects it
                            if (alienRect.contains(superShotRect.center()))
                                // set the alien's life to 0, the alien dies
                                aliens[i].life = 0;

                        // start a loop to check all shots, starting from the last one
                        foreach_reverse (shotPos; shotsPositions)
                        {
                            // define a rectangle around the shot
                            shotRect = Rectangle(shotPos.x, shotPos.y, shotPos.x + primFire.width(), shotPos.y + primFire.height());

                            // if it totally enters the rectangle of the alien
                            if (alienRect.contains(shotRect))
                            {
                                 // remove it from the array (hence the reverse loop starting from the last one)
                                shotsPositions.length--;
                                // update the alien's life
                                aliens[i].life--;
                            }
                        }

                        // if your ship touches an alien
                        if (alienRect.overlaps(shipRect))
                            // update this boolean, you lose the game
                            lost = true;
                    }

                    // if the alien's life reaches 0
                    if (!aliens[i].destroyed && aliens[i].life <= 0)
                    {
                        // update the alien's state
                        aliens[i].destroyed = true;
                        // this boolean becomes true to give you an upgrade with double fire after you've destroyed 3 aliens
                        upgradeEarned = aliens[0].destroyed && aliens[1].destroyed && aliens[2].destroyed;
                        // play the sound of the alien's death
                        music.playOgg("sounds/alien death sound.ogg");
                    }
                }
        }
    },
    // register mouse events
    (MouseEvent event)
    {
        // if you are still playing, then we move the ship and shoot
        if (!(won || lost))
            // if you've moved the mouse arrow
            if (event.type == MouseEventType.motion)
                // update the ship's position, we make the ship be wherever the mouse arrow is
                shipPosition.x = event.x, shipPosition.y = event.y;
            // if you've pressed a mouse button
            else if (event.type == MouseEventType.buttonPressed)
                // if you've pressed the left mouse button
                if (event.button == MouseButton.left)
                {
                    // add the new shot to the array of shots
                    shotsPositions ~= Point(event.x, event.y);

                    // if you already have the double shot upgrade
                    if (upgradeEarned)
                        // add another shot to the array
                        shotsPositions ~= Point(event.x + 30, event.y);

                    // play the sound of shooting
                    music.playOgg("sounds/shoot sound.ogg");
                }
                // if you've pressed the right mouse button and you still have the super shot, then you fire the super shot
                else if (event.button == MouseButton.right && !superShotFired)
                {
                    // set this boolean to true
                    superShotFired = true;
                    // define the position of the super shot
                    superShotPosition = Point(event.x - 25, event.y - 90);
                    // play the super shot sound
                    music.playOgg("sounds/super shoot sound.ogg");
                }
    },
    // register key events
    (KeyEvent event)
    {
        // if you are still playing and the key was the Space, then we activate the turbo
        if (!(won || lost) && event.key == Key.Space)
            // if you've pressed the key
            if (event.pressed)
            {
                // if your speed is still normal
                if (movingSpeed == 1)
                {
                    // up the speed from 1 to 5
                    movingSpeed = 5;
                    // update the costume of the ship's sprite
                    ship = shipTurbo;
                    // play the turbo sound
                    music.playOgg("sounds/turbo sound.ogg");
                }
            }
            // if you've released the Space key
            else
            {
                // set the speed back to normal
                movingSpeed = 1;
                // set the costume back to normal
                ship = shipNormal;
            }
    });
}
