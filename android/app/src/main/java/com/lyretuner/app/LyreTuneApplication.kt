package com.lyretuner.app

import android.app.Application
import android.util.Log

class LyreTuneApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Set up global exception handler
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            Log.e("LyreTune", "Uncaught exception in thread ${thread.name}", throwable)
            
            // Log the full stack trace
            throwable.printStackTrace()
            
            // You could also save crash logs to a file here if needed
            
            // Call the default handler to properly terminate the app
            // This prevents the app from appearing frozen
            val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
            defaultHandler?.uncaughtException(thread, throwable)
        }
        
        // Set up Coroutine exception handler
        System.setProperty(
            "kotlinx.coroutines.debug",
            if (BuildConfig.DEBUG) "on" else "off"
        )
    }
}