package com.redsunholdings.game.widget;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.SizeF;
import android.widget.RemoteViews;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/**
 * Sol home screen widget: income an hour. One row tall, 1 to 4 cells wide.
 * The game writes files/widget.json (Godot's user://) each time it saves;
 * this only reads it. Nothing here can change the game or its save.
 */
public class SolWidget extends AppWidgetProvider {

	private static final int[] LAYOUTS = {
		com.godot.game.R.layout.sol_widget_1,
		com.godot.game.R.layout.sol_widget_2,
		com.godot.game.R.layout.sol_widget_3,
		com.godot.game.R.layout.sol_widget_4,
	};
	// Widths (dp) where each layout starts: about 1, 2, 3 and 4 cells.
	private static final float[] WIDTHS = {40f, 110f, 180f, 250f};

	@Override
	public void onUpdate(Context ctx, AppWidgetManager mgr, int[] ids) {
		for (int id : ids) {
			draw(ctx, mgr, id);
		}
	}

	@Override
	public void onAppWidgetOptionsChanged(Context ctx, AppWidgetManager mgr, int id, Bundle opts) {
		draw(ctx, mgr, id);
	}

	/** Called from the game (JavaClassWrapper) after it writes a new figure. */
	public static void refresh() {
		Context ctx = appContext();
		if (ctx != null) {
			refresh(ctx);
		}
	}

	public static void refresh(Context ctx) {
		try {
			AppWidgetManager mgr = AppWidgetManager.getInstance(ctx);
			int[] ids = mgr.getAppWidgetIds(new ComponentName(ctx, SolWidget.class));
			for (int id : ids) {
				draw(ctx, mgr, id);
			}
		} catch (Exception e) {
			// A widget must never take the game down.
		}
	}

	private static Context appContext() {
		try {
			Object app = Class.forName("android.app.ActivityThread").getMethod("currentApplication").invoke(null);
			return app instanceof Context ? (Context) app : null;
		} catch (Exception e) {
			return null;
		}
	}

	private static void draw(Context ctx, AppWidgetManager mgr, int id) {
		String[] t = read(ctx);
		PendingIntent open = openGame(ctx);
		RemoteViews views;
		if (Build.VERSION.SDK_INT >= 31) {
			Map<SizeF, RemoteViews> map = new HashMap<>();
			for (int i = 0; i < LAYOUTS.length; i++) {
				map.put(new SizeF(WIDTHS[i], 40f), build(ctx, LAYOUTS[i], i, t, open));
			}
			views = new RemoteViews(map);
		} else {
			Bundle o = mgr.getAppWidgetOptions(id);
			int w = o == null ? 0 : o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0);
			int i = 0;
			for (int k = 0; k < WIDTHS.length; k++) {
				if (w >= WIDTHS[k]) {
					i = k;
				}
			}
			views = build(ctx, LAYOUTS[i], i, t, open);
		}
		mgr.updateAppWidget(id, views);
	}

	private static RemoteViews build(Context ctx, int layout, int size, String[] t, PendingIntent open) {
		RemoteViews v = new RemoteViews(ctx.getPackageName(), layout);
		if (t == null) {
			v.setTextViewText(com.godot.game.R.id.sol_rate, "Open");
			v.setTextViewText(com.godot.game.R.id.sol_unit, size == 0 ? "Sol" : "Sol to start");
		} else {
			v.setTextViewText(com.godot.game.R.id.sol_rate, size == 0 ? t[1] : t[0]);
			v.setTextViewText(com.godot.game.R.id.sol_unit, size == 0 ? "/h" : (size == 1 ? "an hour" : "income an hour"));
		}
		if (open != null) {
			v.setOnClickPendingIntent(com.godot.game.R.id.sol_root, open);
		}
		return v;
	}

	private static PendingIntent openGame(Context ctx) {
		Intent i = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
		if (i == null) {
			return null;
		}
		i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		return PendingIntent.getActivity(ctx, 0, i, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
	}

	/** {rate, rate_short}, or null if the game hasn't written one yet. */
	private static String[] read(Context ctx) {
		File f = new File(ctx.getFilesDir(), "widget.json");
		if (!f.isFile() || f.length() > 4096) {
			return null;
		}
		try (FileInputStream in = new FileInputStream(f)) {
			byte[] b = new byte[(int) f.length()];
			int n = 0;
			while (n < b.length) {
				int r = in.read(b, n, b.length - n);
				if (r < 0) {
					break;
				}
				n += r;
			}
			JSONObject j = new JSONObject(new String(b, 0, n, StandardCharsets.UTF_8));
			String rate = j.optString("rate", "");
			if (rate.isEmpty()) {
				return null;
			}
			return new String[] {rate, j.optString("rate_short", rate)};
		} catch (Exception e) {
			return null;
		}
	}
}
