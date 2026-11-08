package com.mrajkishor.varnika

import android.app.Application
import com.mrajkishor.varnika.vpn.TunnelManager

class VarnikaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        TunnelManager.init(this)
    }
}
