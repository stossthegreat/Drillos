package com.example.drillos

import android.app.Application
import androidx.multidex.MultiDex
import androidx.multidex.MultiDexApplication

class MainApplication : MultiDexApplication() {
    override fun onCreate() {
        super.onCreate()
        // You can initialize SDKs here if needed
    }
}
