int fg[][][];
boolean fgbool[][];

int outlineWidth = 12;

int blocksX = 8;
int blocksY = 15;
int blockSize = 50;

boolean newShape = true;
boolean justTicked = false;

int currShapeParams[][]; //persistent memory to reference the six shapes
int currShapeColor[];
int currShapeCoords[]; //actual xy of the shape on the board
int currShapeType;

boolean tickTrigger = false;

int tickTimeMs = 1000;

//for rotations
boolean horizontal;
  
OPC opc;
//PImage dot;




void setup()
{
  
  size(1000, 1200);
  background(0);
  
  //Draw board
  reset();
  
  //Initialize all other arrays
  currShapeParams = new int[4][2];
  currShapeColor = new int[3];
  currShapeCoords = new int[2];
  
  //Connect to server
  opc = new OPC(this, "127.0.0.1", 7890);
  
  //Configure LEDs
  for(int i = 0; i < 16; i++)
    {
      opc.ledStrip(i*180, 180,
        6+ 18*i, 220 - i*4 + 240, 
        4.4, 
        PI * 0.5, 
        false);
    }
    for(int i = 16; i < 24; i++)
    {
      opc.ledStrip(i*180, 180,
        6+ 18*i, 220 - 16*4 + 240, 
        4.4, 
        PI * 0.5, 
        false);
    }
  /*for(int level = 0; level < 3; level++)
  {
    for(int i = 0; i < 16; i++)
    {
      opc.ledStrip(level*64*24 + i*64, 64,
        6+ 18*i, 220 - i*6 + level*260, 
        3.7, 
        PI * 0.5, 
        false);
    }
    for(int i = 16; i < 24; i++)
    {
      opc.ledStrip(level*64*24 + i*64, 64,
        6+ 18*i, 220 - 16*6 + level*260, 
        3.7, 
        PI * 0.5, 
        false);
    }
  }*/
  
  //dot = loadImage("dot.png");
  
  
}

void draw()
{
  //fill(0, 0, 255);
  //rect(mouseX, mouseY, 30, 30);
 if(millis() % tickTimeMs >= 500)
 {
   justTicked = false;
 }
 
 //Operate on game ticks
 if((millis() % tickTimeMs < 500 && !justTicked) || tickTrigger)
 {
   justTicked = true;
   tickTrigger = false;
   
   
   //Load shape onto board if now is the time
   if(newShape)
   {
     newShape = false;
     
     currShapeCoords[0] = 0;
     currShapeCoords[1] = -1; //will get moved down by 1 immediately
     horizontal = true;
     
     //Configure new shape
     currShapeType = (int)random(6);
     
     if(currShapeType == 0)
     {
       currShapeColor[0] = 255;
       currShapeColor[1] = 0;
       currShapeColor[2] = 0;
       
       currShapeParams[0][0] = 0;
       currShapeParams[0][1] = 0;
       currShapeParams[1][0] = 1;
       currShapeParams[1][1] = 0;
       currShapeParams[2][0] = 2;
       currShapeParams[2][1] = 0;
       currShapeParams[3][0] = 3;
       currShapeParams[3][1] = 0;       
     }
     if(currShapeType == 1)
     {
       currShapeColor[0] = 200;
       currShapeColor[1] = 55;
       currShapeColor[2] = 0;
       
       currShapeParams[0][0] = 0;
       currShapeParams[0][1] = 0;
       currShapeParams[1][0] = 1;
       currShapeParams[1][1] = 0;
       currShapeParams[2][0] = 2;
       currShapeParams[2][1] = 0;
       currShapeParams[3][0] = 0;
       currShapeParams[3][1] = 1;
     }
     if(currShapeType == 2)
     {
       currShapeColor[0] = 128;
       currShapeColor[1] = 128;
       currShapeColor[2] = 0;
       
       currShapeParams[0][0] = 0;
       currShapeParams[0][1] = 0;
       currShapeParams[1][0] = 1;
       currShapeParams[1][1] = 0;
       currShapeParams[2][0] = 0;
       currShapeParams[2][1] = 1;
       currShapeParams[3][0] = 1;
       currShapeParams[3][1] = 1;
     }
     if(currShapeType == 3)
     {
       currShapeColor[0] = 0;
       currShapeColor[1] = 255;
       currShapeColor[2] = 0;
       
       currShapeParams[0][0] = 0;
       currShapeParams[0][1] = 0;
       currShapeParams[1][0] = 1;
       currShapeParams[1][1] = 0;
       currShapeParams[2][0] = 2;
       currShapeParams[2][1] = 0;
       currShapeParams[3][0] = 2;
       currShapeParams[3][1] = 1;
     }
     if(currShapeType == 4)
     {
       currShapeColor[0] = 0;
       currShapeColor[1] = 0;
       currShapeColor[2] = 255;
       
       currShapeParams[0][0] = 0;
       currShapeParams[0][1] = 0;
       currShapeParams[1][0] = 1;
       currShapeParams[1][1] = 0;
       currShapeParams[2][0] = 1;
       currShapeParams[2][1] = 1;
       currShapeParams[3][0] = 2;
       currShapeParams[3][1] = 1;
     }
     if(currShapeType > 4)
     {
       currShapeColor[0] = 128;
       currShapeColor[1] = 0;
       currShapeColor[2] = 128;
       
       currShapeParams[0][0] = 0;
       currShapeParams[0][1] = 1;
       currShapeParams[1][0] = 1;
       currShapeParams[1][1] = 1;
       currShapeParams[2][0] = 1;
       currShapeParams[2][1] = 0;
       currShapeParams[3][0] = 2;
       currShapeParams[3][1] = 0;
     }
     
     
     
   } //endif new shape
   
  
 //Move new shape down one square
 currShapeCoords[1] += 1;
 
 //Check for collision or out of bounds
 boolean collision = false;
 boolean gameover = false;
 for(int i = 0; i < 4; i++)
 {
   int x = currShapeParams[i][0] + currShapeCoords[0];
   int y = currShapeParams[i][1] + currShapeCoords[1];
   
   if(y >= blocksY)
   {
     collision = true;
     break; //Break out to avoid buffer overflow on next if statement
   }
   
   if(fgbool[x][y])
     collision = true;   
 } 
 
 //Place shape if collision
 if(collision)
 {
   currShapeCoords[1] -= 1;
   
   //If we are above the screen, game over
   if(currShapeCoords[1] < 0)
   {
     newShape = true;
     currShapeCoords[1] += 1;
     gameover = true;
   }
   else //we are good
   {
        
     for(int i = 0; i < 4; i++)
     {
       int x = currShapeParams[i][0] + currShapeCoords[0];
       int y = currShapeParams[i][1] + currShapeCoords[1];
       
       fgbool[x][y] = true;
       fg[x][y][0] = currShapeColor[0];
       fg[x][y][1] = currShapeColor[1];
       fg[x][y][2] = currShapeColor[2];
     }
     
     //Clear line if necessary
     boolean cleared = true;
     for(int x = 0; x < blocksX; x++)
     {
        if( !( fgbool[x][blocksY-1] ) ) cleared = false;
     }
     if(cleared)
     {
       for(int x = 0; x < blocksX; x++)
       {
         for(int y = blocksY-1; y > 0; y--)
         {
           fgbool[x][y] = fgbool[x][y-1];
           fg[x][y][0] = fg[x][y-1][0];
           fg[x][y][1] = fg[x][y-1][1];
           fg[x][y][2] = fg[x][y-1][2];
         }
       }
     }
     
     newShape = true;
   }//end else
   
 }
 
 //Render
 
 
 //Clear screen and draw the rest of the already-placed shapes
 for(int x = 0; x < blocksX; x++)
  {
    for(int y = 0; y < blocksY; y++)
    {
      fill(fg[x][y][0], fg[x][y][1], fg[x][y][2]);
      rect(
        x*blockSize + outlineWidth, 
        y*blockSize + outlineWidth,
        blockSize, 
        blockSize
        );
    }//end for y
  }//end for x

 
 //Draw current shape
 fill(currShapeColor[0], currShapeColor[1], currShapeColor[2]);
 for(int i = 0; i < 4; i++)
 {
   rect(
     currShapeCoords[0] * blockSize + currShapeParams[i][0] * blockSize + outlineWidth,
     currShapeCoords[1] * blockSize + currShapeParams[i][1] * blockSize + outlineWidth,
     blockSize, 
     blockSize
     );     
 }//end for
 
 //int dotSize = 200;
 //image(dot, mouseX - dotSize/2, mouseY - dotSize/2, dotSize, dotSize);
 //Reset if game over
 if(gameover) reset();
   
 }//endif game tick 
}//end draw()

void keyPressed()
{
 if(key == CODED)
 {
   if(keyCode == DOWN)
   {
     tickTrigger = true;
   }
   if(keyCode == RIGHT)
   {
     currShapeCoords[0] += 1;

     for(int i = 0; i < 4; i++)
     {
       int x = currShapeParams[i][0] + currShapeCoords[0];
       int y = currShapeParams[i][1] + currShapeCoords[1];
       
       if(y >= blocksY)
         break;
   
       if(x >= blocksX)
       {
         currShapeCoords[0] -= 1;
         break;
       }
   
       if(fgbool[x][y]) 
         currShapeCoords[0] -= 1;
     } 
     
     render();
   }
   if(keyCode == LEFT)
   {
     currShapeCoords[0] -= 1;

     for(int i = 0; i < 4; i++)
     {
       int x = currShapeParams[i][0] + currShapeCoords[0];
       int y = currShapeParams[i][1] + currShapeCoords[1];
       
       if(y >= blocksY)
         break;
   
       if(x < 0)
       {
         currShapeCoords[0] += 1;
         break;
       }
   
       if(fgbool[x][y]) 
         currShapeCoords[0] += 1;
     } 
     
     render();
   }
 }
 
 if(key == 'R') 
 {
   reset();
   newShape = true;
 }
 if(key == 'z')
   rotateCCW();
 
}

void keyReleased()
{
 
}

void reset()
{
  //Make outline
  fill(255, 255, 255);
  rect(0, 0, blocksX * blockSize + 2 * outlineWidth, blocksY * blockSize + 2 * outlineWidth);
  fill(0, 0, 0);
  rect(outlineWidth, outlineWidth, blocksX * blockSize, blocksY * blockSize);
  
  //Initialize main arrays
  fg = new int[blocksX][blocksY][3];
  fgbool = new boolean[blocksX][blocksY];
  for(int x = 0; x < blocksX; x++)
  {
    for(int y = 0; y < blocksY; y++)
    {
      fgbool[x][y] = false;
      for(int c = 0; c < 3; c++)
      {
        fg[x][y][c] = 0;
      }
    }
  } 
}

void render()
{
 //Make outline
  fill(255, 255, 255);
  rect(0, 0, blocksX * blockSize + 2 * outlineWidth, blocksY * blockSize + 2 * outlineWidth);
  fill(0, 0, 0);
  rect(outlineWidth, outlineWidth, blocksX * blockSize, blocksY * blockSize);
  
 //Clear screen and draw the rest of the already-placed shapes
 for(int x = 0; x < blocksX; x++)
  {
    for(int y = 0; y < blocksY; y++)
    {
      fill(fg[x][y][0], fg[x][y][1], fg[x][y][2]);
      rect(
        x*blockSize + outlineWidth, 
        y*blockSize + outlineWidth,
        blockSize, 
        blockSize
        );
    }//end for y
  }//end for x

 
 //Draw current shape
 fill(currShapeColor[0], currShapeColor[1], currShapeColor[2]);
 for(int i = 0; i < 4; i++)
 {
   rect(
     currShapeCoords[0] * blockSize + currShapeParams[i][0] * blockSize + outlineWidth,
     currShapeCoords[1] * blockSize + currShapeParams[i][1] * blockSize + outlineWidth,
     blockSize, 
     blockSize
     );     
 }//end for
}

void rotateCCW()
{
  int newShapeParams[][] = new int[4][2];
  
  if(currShapeType == 0)
  {
     newShapeParams[0][0] = 0;
     newShapeParams[0][1] = 0;
     newShapeParams[1][0] = 0;
     newShapeParams[1][1] = 1;
     newShapeParams[2][0] = 0;
     newShapeParams[2][1] = 2;
     newShapeParams[3][0] = 0;
     newShapeParams[3][1] = 3; 
  }
  else if(currShapeType == 2)
  {
    for(int i = 0; i < 4; i++)
     {
       newShapeParams[i][0] = currShapeParams[i][0];
       newShapeParams[i][1] = currShapeParams[i][1];
     }
       
  }
  else
  {
    if(horizontal)
    {
     for(int i = 0; i < 4; i++)
     {
       newShapeParams[i][0] = currShapeParams[i][1];
       newShapeParams[i][1] = 2 - currShapeParams[i][0];       
     }
     horizontal = false;
    }
    else
    {
     for(int i = 0; i < 4; i++)
     {
       newShapeParams[i][0] = currShapeParams[i][1];
       newShapeParams[i][1] = 1 - currShapeParams[i][0];       
     }
     horizontal = true;
    }
    
  }
  
  //Check for collisions!
  boolean collision = false;
  for(int i = 0; i < 4; i++)
  {
   int x = newShapeParams[i][0] + currShapeCoords[0];
   int y = newShapeParams[i][1] + currShapeCoords[1];
   
   if(y >= blocksY || y < 0 || x >= blocksX || x < 0)
   {
     collision = true;
     break; //Break out to avoid buffer overflow on next if statement
   }
   
   if(fgbool[x][y])
     collision = true;   
  }
  
  if(!collision)
  {
    currShapeParams = newShapeParams;
    render();
  }
  
}