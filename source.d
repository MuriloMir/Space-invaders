// these 2 lines are to make sure the prompt window will not pop up along with the game's GUI
pragma(linkerDirective, "/subsystem:windows");
pragma(linkerDirective, "/entry:mainCRTStartup");

import arsd.image: loadImageFromFile;
import arsd.simpleaudio : AudioOutputThread;
import arsd.simpledisplay : Image, Key, KeyEvent, MemoryImage, MouseButton, MouseEvent, MouseEventType, Point, Rectangle, ScreenPainter, SimpleWindow, Size, Sprite;

void main()
{
    // here we create and start the audio thread
    AudioOutputThread music = AudioOutputThread(true);
    // here we create the GUI window
    SimpleWindow window = new SimpleWindow(1000, 400, "Space Invaders");
    // first we load the memory images
    MemoryImage memBackground = loadImageFromFile("images/background.png"), memShipNormal = loadImageFromFile("images/ship normal.png"),
                memShipTurbo = loadImageFromFile("images/ship turbo.png"), memPrimFire = loadImageFromFile("images/primary fire.png"),
                memSuperFire = loadImageFromFile("images/super fire.png"), memDefeat = loadImageFromFile("images/defeat.png"),
                memEnd = loadImageFromFile("images/end.png");
    // these are the actual images and sprites you'll see in the game
    Image background = Image.fromMemoryImage(memBackground), defeat = Image.fromMemoryImage(memDefeat), end = Image.fromMemoryImage(memEnd);
    Sprite shipNormal = new Sprite(window, Image.fromMemoryImage(memShipNormal, true)), shipTurbo = new Sprite(window, Image.fromMemoryImage(memShipTurbo, true)),
           primFire = new Sprite(window, Image.fromMemoryImage(memPrimFire, true)), superFire = new Sprite(window, Image.fromMemoryImage(memSuperFire, true)), ship = shipNormal;
    // here we declare all variables we'll be using
    // first these booleans are necessary to keep track of the current state of the player and the game
    bool superShotFired, upgradeEarned, won, lost;
    // 'backgroundHeight' will control current position of the background, which will be rolling down the window as you play, and 'movingSpeed' will control the speed of the ship
    int movingSpeed = 1, backgroundHeight = -2400;
    // these variables will keep track of the ship's position and the super shot position (in case you fire it)
    Point shipPosition = Point(400, 300), superShotPosition;
    // here we have an array where we will place the current position of every single primary shot (not counting the super shot) you fire
    Point[] shotsPositions;
    // here we create an array full of aliens that will attack you, the struct 'Alien' is defined below
    Alien[6] aliens;

    // now we will declare all delegates we will be using during the game's event loop, they do what their names suggest
    void drawEverything(ScreenPainter painter)
    {
        // first we draw the background, it's a very big image that I have edited on MS Paint
        painter.drawImage(Point(0, backgroundHeight), background);
        // then we draw all shots (primary fire) and update their position for the next iteration (taking into account the player's speed)
        foreach (i; 0 .. shotsPositions.length)
        {
            primFire.drawAt(painter, shotsPositions[i]);
            shotsPositions[i].y -= 15 + movingSpeed;
        }
        // here we draw the super shot in case you have fired it and it still hasn't gone over the window's edge, then we update it's position
        if (superShotFired && superShotPosition.y + superFire.height() > 0)
        {
            superFire.drawAt(painter, superShotPosition);
            superShotPosition.y -= (15 + movingSpeed);
        }
        //here we draw each alien on the window, one at a time
        foreach (i; 0 .. 6)
        {
            //first we decide if we will draw the alive or the dead sprite costume in case you've destroyed it
            if (aliens[i].destroyed)
                aliens[i].dead.drawAt(painter, aliens[i].position);
            else
            {
                aliens[i].alive.drawAt(painter, aliens[i].position);
                //if it's still alive then we check if it has totally passed by your ship (in which case you lose)
                if (aliens[i].position.y > 400)
                    lost = true;
            }
            // here we update the alien's position based on your current speed (your speed changes if you use the turbo)
            aliens[i].position.y += movingSpeed;
        }
        // and last but not least, we draw your ship
        ship.drawAt(painter, shipPosition);
    }

    void damageAliensIfYouHitThemOrLoseIfYouCrashIntoThem()
    {
        // for each alien, one at a time, we will check if you have hit it or crashed into it
        foreach (i; 0 .. 6)
        {
            // if the alien is still alive and it hasn't yet totally passed by you
            if (!aliens[i].destroyed && aliens[i].position.y + aliens[i].alive.height() > 0 && aliens[i].position.y < 400)
            {
                // we create a rectangle around the alien since the computer only understands rectangles
                Rectangle alienRect = Rectangle(aliens[i].position, Size(aliens[i].alive.width(), aliens[i].alive.height())),
                          shipRect = Rectangle(shipPosition, Size(ship.width(), ship.height()));
                // in case you've used the super shot
                if (superShotFired)
                {
                    // we create a rectangle around the super shot and then check if it DEEPLY intersects the rectangle around the alien
                    Rectangle superShotRect = Rectangle(superShotPosition, Size(superFire.width(), superFire.height()));
                    // if the center of the super shot is inside the alien's rectangle then it deeply intersects it, in this case the alien dies
                    if (alienRect.contains(superShotRect.center()))
                        aliens[i].life = 0;
                }
		// here we check each primary fire you've shot to see if it hit an alien, in which case it must disappear, for that we must shorten the array of
		// shots positions and it does so by abandoning the last element, hence we are iterating in reverse, to start from the last
                foreach_reverse (shotPos; shotsPositions)
                {
                    // we create a rectangle around the shot
                    Rectangle shotRect = Rectangle(shotPos, Size(primFire.width(), primFire.height()));
		    // if it totally enters the rectangle of the alien then it disappears (gets removed from array) and the alien's life is updated
                    if (alienRect.contains(shotRect))
                    {
                        shotsPositions.length--;
                        aliens[i].life--;
                    }
                }
                // if your ship touches an alien then it breaks, meaning you lose the game
                if (alienRect.overlaps(shipRect))
                    lost = true;
            }
            // if the alien's life reaches 0 then it must die, so we update its state
            if (!aliens[i].destroyed && aliens[i].life <= 0)
            {
                aliens[i].destroyed = true;
                // here we give you an upgrade with double fire after you've destroyed 3 aliens
                upgradeEarned = aliens[0].destroyed && aliens[1].destroyed && aliens[2].destroyed;
                // and we play the sound of the alien's death
                music.playOgg("sounds/alien death sound.ogg");
            }
        }
    }

    void moveShipAndShoot(MouseEvent event)
    {
        // we make the ship be wherever the mouse arrow is, so it follows the mouse arrow as you move it
        if (event.type == MouseEventType.motion)
            shipPosition.x = event.x, shipPosition.y = event.y;
        // in case you choose to fire then it adds the new shot to the array of shots and adds a twin in case your gun has been upgraded to double fire
        else if (event.type == MouseEventType.buttonPressed)
            if (event.button == MouseButton.left)
            {
                shotsPositions ~= Point(event.x, event.y);
                if (upgradeEarned)
                    shotsPositions ~= Point(event.x + 30, event.y);
                // then it makes the sound of shooting
                music.playOgg("sounds/shoot sound.ogg");
            }
            // in case you haven't used your super shot yet and you decide to use it now (you can only use it once)
            else if (event.button == MouseButton.right && !superShotFired)
            {
                // we let the game know you've used it, then we update the super shot position and play its sound
                superShotFired = true;
                superShotPosition = Point(event.x - 25, event.y - 90);
                music.playOgg("sounds/super shoot sound.ogg");
            }
    }

    void activateTurboEngine(KeyEvent event)
    {
        // if you press and hold Space then you fly at turbo speed, it returns to normal speed once you release Space
        if (event.key == Key.Space)
            if (event.pressed)
            {
                if (movingSpeed == 1)
                {
                    // we up the speed from 1 to 5, update the costume of the ship's sprite and play the turbo sound
                    movingSpeed = 5;
                    ship = shipTurbo;
                    music.playOgg("sounds/turbo sound.ogg");
                }
            }
            else
            {
				// here we set it all back to normal
                movingSpeed = 1;
                ship = shipNormal;
            }
    }

    // here we will create and fill the array for 'Alien' structs
    // first we get the names of the image files
    string[6] imgNamesAlive = ["images/alien0alive.png", "images/alien1alive.png", "images/alien2alive.png", "images/alien3alive.png", "images/alien4alive.png",
                               "images/alien5alive.png"],
              imgNamesDead = ["images/alien0dead.png", "images/alien1dead.png", "images/alien2dead.png", "images/alien3dead.png", "images/alien4dead.png", "images/alien5dead.png"];
    // then we get the start points of each alien (I've chose them myself arbitrarily)
    Point[6] startPoints = [Point(100, -120), Point(600, -300), Point(200, -500), Point(800, -700), Point(250, -900), Point(400, -1750)];
    // this variable will keep track of the alien's life
    int life;
    // now we will create each of the 6 aliens, one at a time
    foreach (i; 0 .. 6)
    {
        // first we load the memory image and turn it into a sprite
        MemoryImage memAlive = loadImageFromFile(imgNamesAlive[i]), memDead = loadImageFromFile(imgNamesDead[i]);
        Sprite imgAlive = new Sprite(window, Image.fromMemoryImage(memAlive, true)), imgDead = new Sprite(window, Image.fromMemoryImage(memDead, true));
        // then we declare each alien's struct with the life, the start point, the image while alive and the image after you kill it, notice
        // the variable life is incremented by 5 at each iteration, that's because each alien must be stronger than its predecessor
        aliens[i] = Alien(life += 5, startPoints[i], imgAlive, imgDead);
    }

    // here we start playing the background music
    music.playOgg("sounds/background.ogg", true);
    // we don't want the cursor to be on top of the ship, so we hide it
    window.hideCursor();

    // here we finally start the window's event loop, I figured 30 msecs is a reasonable time for the magic to happen
    window.eventLoop(30,
    {
        ScreenPainter painter = window.draw();
        // here we do the actual game until you win or lose, first we draw everything on the window, to do that we must first
        // check if you've finished the game, if so then we display the corresponding image
        if (won)
            painter.drawImage(Point(0, 0), end);
        else if (lost)
            painter.drawImage(Point(0, 0), defeat);
        else
            //this delegate, just like the others you will see in this code, can be found defined above
            drawEverything(painter);

        if (!(won || lost))
        {
            // here we only update the background's height and check if you have finally reached the end of the game (in which case you win)
            backgroundHeight += movingSpeed;
            if (backgroundHeight > -5)
                won = true;
            else
                // this delegate will do what its name suggests
                damageAliensIfYouHitThemOrLoseIfYouCrashIntoThem();
        }
    },
    // here we react to mouse input by moving the ship and shooting
    (MouseEvent event)
    {
        if (!(won || lost))
            moveShipAndShoot(event);
    },
    // here we react to keyboard input by using the turbo
    (KeyEvent event)
    {
        if (!(won || lost))
            activateTurboEngine(event);
    });
}

// a struct to represent each alien, it contains the alien's life, position, the costumes of its sprite and a boolean to know if it's been destroyed
struct Alien
{
    int life;
    Point position;
    Sprite alive, dead;
    bool destroyed;
}
