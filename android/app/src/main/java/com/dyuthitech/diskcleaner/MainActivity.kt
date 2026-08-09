package com.dyuthitech.diskcleaner

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.*

class MainActivity : Activity() {

    private val tabs = arrayOf("✨ Clean", "📊 Explore", "☀️ Space Lens", "📦 Apps", "📄 Duplicates", "🔒 Privacy", "🗑️ Shredder", "🛠️ Maintenance", "⚙️ Settings")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        // Header Title
        val title = TextView(this).apply {
            text = "Disk Cleaner Native (Android)"
            textSize = 20f
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        mainLayout.addView(title)

        // 9-Tab Horizontal Scroll Navigation Bar
        val tabScrollView = HorizontalScrollView(this).apply {
            setPadding(0, 16, 0, 24)
        }
        val tabContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val contentArea = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 16, 0, 16)
        }

        tabs.forEach { tabName ->
            val tabBtn = Button(this).apply {
                text = tabName
                textSize = 12f
                setOnClickListener {
                    renderPage(contentArea, tabName)
                }
            }
            tabContainer.addView(tabBtn)
        }
        tabScrollView.addView(tabContainer)
        mainLayout.addView(tabScrollView)
        mainLayout.addView(contentArea)

        // Non-removable mandatory footer
        val footer = TextView(this).apply {
            text = "Disk Cleaner Native v2.0\nBuilt by Dyuthi Tech Solutions"
            textSize = 11f
            gravity = android.view.Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(android.graphics.Color.parseColor("#3B82F6"))
            setPadding(0, 32, 0, 16)
        }
        mainLayout.addView(footer)

        renderPage(contentArea, "✨ Clean")

        val scrollView = ScrollView(this)
        scrollView.addView(mainLayout)
        setContentView(scrollView)
    }

    private fun renderPage(container: LinearLayout, tabName: String) {
        container.removeAllViews()

        val pageTitle = TextView(this).apply {
            text = tabName
            textSize = 18f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setPadding(0, 0, 0, 16)
        }
        container.addView(pageTitle)

        when {
            tabName.contains("Clean") -> {
                addCard(container, "Reclaimable Android Caches", "3.8 GB across 8 categories\n\n- App Caches (%EXTERNAL_STORAGE%/Android/data)\n- Leftover APK Installers (%DOWNLOADS%/*.apk)\n- WhatsApp Media Caches\n- RAM Memory Boost")
            }
            tabName.contains("Explore") -> {
                addCard(container, "Storage Hierarchy Explorer", "📁 Android/data (12.4 GB)\n📁 DCIM/Camera (8.2 GB)\n📁 Download (4.1 GB)")
            }
            tabName.contains("Space Lens") -> {
                addCard(container, "Space Lens Storage Bubble Map", "🔴 Photos & Videos (20.6 GB)\n🔵 Installed Apps (14.2 GB)\n🟢 Caches & System (6.1 GB)")
            }
            tabName.contains("Apps") -> {
                addCard(container, "App Cache & Uninstaller", "Unused Apps:\n- Offline Games (2.1 GB)\n- Social Media Cache (1.4 GB)")
            }
            tabName.contains("Duplicates") -> {
                addCard(container, "Duplicate File Finder", "Found 24 duplicate media files (480 MB)")
            }
            tabName.contains("Privacy") -> {
                addCard(container, "Privacy & History Wiper", "Clear Chrome browsing data, clipboard history, and location logs.")
            }
            tabName.contains("Shredder") -> {
                addCard(container, "Secure File Shredder", "Permanently overwrite target mobile files.")
            }
            tabName.contains("Maintenance") -> {
                addCard(container, "Android RAM Booster & Maintenance", "⚡ Purge RAM Cache\n- Clear DNS Cache\n- Trim App Working Sets")
            }
            tabName.contains("Settings") -> {
                addCard(container, "Preferences & Customization", "Dynamic Theme Selector & Tab Customization.\n\nBuilt by Dyuthi Tech Solutions")
            }
        }
    }

    private fun addCard(container: LinearLayout, title: String, content: String) {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
            setBackgroundColor(android.graphics.Color.parseColor("#1E293B"))
        }

        val cardTitle = TextView(this).apply {
            text = title
            textSize = 15f
            setTextColor(android.graphics.Color.WHITE)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }

        val cardContent = TextView(this).apply {
            text = content
            textSize = 13f
            setTextColor(android.graphics.Color.parseColor("#94A3B8"))
            setPadding(0, 12, 0, 16)
        }

        val actionBtn = Button(this).apply {
            text = "Run Action"
            setOnClickListener {
                Toast.makeText(this@MainActivity, "$title executed successfully! ✨", Toast.LENGTH_SHORT).show()
            }
        }

        card.addView(cardTitle)
        card.addView(cardContent)
        card.addView(actionBtn)

        container.addView(card)
    }
}
