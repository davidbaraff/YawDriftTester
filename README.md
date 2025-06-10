This iPhone application illustrates an issue when running an Insta360 Flow Pro 2 gimbal for a long period of time.
To replicate the bug:
 1. Build this application.
 2. With your iPhone in the Insta360 Flow Pro gimbal, make sure the phone is turned to landscape mode.
 3. Ensure that your phone is receiving power from the gimbal, and make sure that the gimbal itself is
    getting power from the wall. You will be running the application for a long time, so you need to
    make sure you don't run out of power.
4. Make sure the green tracking light is on; if not, squeeze the trigger to ensure the light is on.
5. Launch the application. The first time, you may need to allow it access to the camera.
6. The application will periodically modify the yaw value so as to orient the phone to point straight ahead (0 degrees),
   or left (-35 degrees), or right (35 degrees). As the application is left running, it will change orientation
   less often. You can see how long the application has been running (upper left), and when the next orientation
   change will occur. The current yaw angle is displayed in the center of the screen.

7. Shortly after you start the application, take note when the yaw angle is near zero, and the point is pointed straight ahead
   of an object in the camera view that is on or close to the green tracking line. At some point (after many hours),
   when the yaw value indicates it is near zero degrees, you will see that a sizeable offset has crept it; the yaw
   angle reads close to zero, but the actual yaw of the gimbal is left or right of center by more than 10 degrees. Again,
   if you remembered what object was on the green line from before, you'll see that at near 0 degrees yaw, that object
   is very to the left or right of the green line.

8. To see an example of all the above steps, download and watch the following video:
