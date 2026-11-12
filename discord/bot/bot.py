"""Chillan? Discord bot.

Reads relay messages ("CHILLAN1 {json}") posted by the Chillan companion into a hidden raw
channel, removes duplicates (several companions may relay the same event), stores everything in
SQLite, posts cards to the feed channel, keeps one live "Gang status" message up to date, and
answers /gang, /deaths, /levels and /loot.

Settings come from environment variables (see chillan-bot.env.example).
"""
import asyncio
import json
import logging
import os
import time

import discord
from discord import app_commands

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import cards
import recaps
from store import Store

PREFIX = "CHILLAN1 "
TOKEN = os.environ["DISCORD_TOKEN"]
GUILD_ID = int(os.environ["GUILD_ID"])
RAW_ID = int(os.environ["RAW_CHANNEL_ID"])
FEED_ID = int(os.environ["FEED_CHANNEL_ID"])
DB_PATH = os.environ.get("DB_PATH", os.path.join(os.path.dirname(os.path.abspath(__file__)), "chillan.db"))
MAX_AGE = int(os.environ.get("MAX_EVENT_AGE_HOURS", "12")) * 3600  # older events are stored, not posted
STATUS_MIN_GAP = 30
TZ = ZoneInfo(os.environ.get("TIMEZONE", "Europe/Oslo"))
RECAP_HOUR = int(os.environ.get("RECAP_HOUR", "8"))
CATCHUP_QUIET = 90  # seconds without new catch-up events before the summary card is posted

log = logging.getLogger("chillan")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)
store = Store(DB_PATH)
guild_obj = discord.Object(id=GUILD_ID)
status_lock = asyncio.Lock()
last_status_edit = 0.0
catchup = []            # catch-up events waiting to be summarised
catchup_task = None
scheduler_started = False


def embed(d):
    d = {k: v for k, v in d.items() if v is not None}
    return discord.Embed.from_dict(d)


async def feed_channel():
    ch = client.get_channel(FEED_ID)
    return ch or await client.fetch_channel(FEED_ID)


async def update_status(st):
    """Edit the pinned live status message (or create it)."""
    global last_status_edit
    store.set("status", json.dumps(st, ensure_ascii=False))
    store.set("status_at", int(time.time()))
    if time.time() - last_status_edit < STATUS_MIN_GAP:
        return
    async with status_lock:
        last_status_edit = time.time()
        ch = await feed_channel()
        e = embed(cards.status_card(st, time.time()))
        mid = store.get("status_msg")
        if mid:
            try:
                msg = await ch.fetch_message(int(mid))
                await msg.edit(embed=e)
                return
            except (discord.NotFound, discord.Forbidden, discord.HTTPException):
                pass
        msg = await ch.send(embed=e)
        store.set("status_msg", msg.id)
        try:
            await msg.pin()
        except discord.HTTPException:
            pass


async def handle(text):
    try:
        e = json.loads(text[len(PREFIX):])
    except ValueError:
        return
    if not isinstance(e, dict):
        return
    if e.get("k") == "STATUS":
        now = int(time.time())
        for r in e.get("g") or []:
            if len(r) > 6 and r[5]:
                store.set("seen:%s" % r[6], now)
        await update_status(e)
        return
    if not e.get("id"):
        return
    new = store.add(e)
    if not new:
        return
    if e.get("cu"):
        catchup.append(e)
        schedule_catchup()
        return
    fresh = e.get("k") == "TEST" or time.time() - int(e.get("t") or 0) <= MAX_AGE
    d = cards.card(e)
    if d and fresh:
        ch = await feed_channel()
        await ch.send(embed=embed(d))


def schedule_catchup():
    global catchup_task
    if catchup_task and not catchup_task.done():
        catchup_task.cancel()
    catchup_task = asyncio.get_event_loop().create_task(post_catchup())


async def post_catchup():
    await asyncio.sleep(CATCHUP_QUIET)
    items = list(catchup)
    catchup.clear()
    d = recaps.catchup_card(items)
    if d:
        ch = await feed_channel()
        await ch.send(embed=embed(d))


async def pin_commands():
    ch = await feed_channel()
    e = embed(recaps.commands_card())
    mid = store.get("commands_msg")
    if mid:
        try:
            msg = await ch.fetch_message(int(mid))
            await msg.edit(embed=e)
            return
        except discord.HTTPException:
            pass
    msg = await ch.send(embed=e)
    store.set("commands_msg", msg.id)
    try:
        await msg.pin()
    except discord.HTTPException:
        pass


async def run_recaps(now=None):
    """Post yesterday's recap after RECAP_HOUR, and on Mondays the weekly summary (once each)."""
    now = now or datetime.now(TZ)
    if now.hour < RECAP_HOUR:
        return
    today = now.date()
    ch = None
    if store.get("daily_done") != today.isoformat():
        store.set("daily_done", today.isoformat())
        start = datetime.combine(today - timedelta(days=1), datetime.min.time(), TZ)
        end = start + timedelta(days=1)
        d = recaps.daily_card(store.range(start.timestamp(), end.timestamp()), start.strftime("%a %d %b"), start.date().isoformat())
        if d:
            ch = ch or await feed_channel()
            await ch.send(embed=embed(d))
    week_id = "%d-W%02d" % today.isocalendar()[:2]
    if today.weekday() == 0 and store.get("weekly_done") != week_id:
        store.set("weekly_done", week_id)
        end = datetime.combine(today, datetime.min.time(), TZ)
        start = end - timedelta(days=7)
        label = "week %d (%s to %s)" % ((start.isocalendar()[1]), start.strftime("%d %b"), (end - timedelta(days=1)).strftime("%d %b"))
        d = recaps.weekly_card(store.range(start.timestamp(), end.timestamp()), label, week_id, current_status())
        if d:
            ch = ch or await feed_channel()
            await ch.send(embed=embed(d))


async def scheduler():
    while True:
        try:
            await run_recaps()
        except Exception:
            log.exception("recap failed")
        await asyncio.sleep(60)


async def process(msg):
    if msg.channel.id != RAW_ID or not msg.content.startswith(PREFIX):
        return
    try:
        await handle(msg.content)
    except Exception:
        log.exception("could not handle relay message")
        return
    try:
        await msg.delete()
    except discord.HTTPException:
        pass


@client.event
async def on_ready():
    log.info("logged in as %s", client.user)
    global scheduler_started
    tree.copy_global_to(guild=guild_obj)
    await tree.sync(guild=guild_obj)
    try:
        await pin_commands()
    except discord.HTTPException:
        log.exception("could not pin the command list")
    if not scheduler_started:
        scheduler_started = True
        client.loop.create_task(scheduler())
    # anything that arrived while the bot was offline
    try:
        raw = client.get_channel(RAW_ID) or await client.fetch_channel(RAW_ID)
        async for m in raw.history(limit=500, oldest_first=True):
            await process(m)
    except discord.HTTPException:
        log.exception("could not read raw backlog")


@client.event
async def on_message(msg):
    if msg.author == client.user:
        return
    await process(msg)


def current_status():
    s = store.get("status")
    return json.loads(s) if s else {"g": []}


@tree.command(name="gang", description="Who's online, levels and zones")
async def gang(inter: discord.Interaction):
    await inter.response.send_message(embed=embed(cards.status_card(current_status(), int(store.get("status_at", time.time())))))


@tree.command(name="deaths", description="The wall of shame")
async def deaths(inter: discord.Interaction):
    all_d = store.events("DEAD", 0, 5000)
    week = store.events("DEAD", int(time.time()) - 7 * 86400, 5000)
    await inter.response.send_message(embed=embed(cards.deaths_card(all_d, week)))


@tree.command(name="levels", description="The race to 60")
async def levels(inter: discord.Interaction):
    await inter.response.send_message(embed=embed(cards.levels_card(current_status())))


@tree.command(name="loot", description="Recent good drops")
async def loot(inter: discord.Interaction):
    await inter.response.send_message(embed=embed(cards.loot_card(store.events("LOOT", 0, 10))))


def names():
    out = []
    for r in current_status().get("g") or []:
        out += [str(r[0]), str(r[1])]
    return sorted(set(out), key=str.lower)


async def name_complete(inter: discord.Interaction, current: str):
    cur = current.lower()
    return [app_commands.Choice(name=n, value=n) for n in names() if cur in n.lower()][:25]


@tree.command(name="whois", description="Profile of one gang member")
@app_commands.describe(name="Alias or character name")
@app_commands.autocomplete(name=name_complete)
async def whois(inter: discord.Interaction, name: str):
    st = current_status()
    row, pid = recaps._match(name, st.get("g") or [], [])
    seen = store.get("seen:%s" % pid) if pid else None
    await inter.response.send_message(embed=embed(recaps.whois_card(name, st, store.all(), int(seen) if seen else None)))


@tree.command(name="stats", description="Numbers for the whole gang, or one person")
@app_commands.describe(name="Optional: alias or character name")
@app_commands.autocomplete(name=name_complete)
async def stats(inter: discord.Interaction, name: str = None):
    await inter.response.send_message(embed=embed(recaps.stats_card(name, current_status(), store.all())))


if __name__ == "__main__":
    client.run(TOKEN, log_handler=None)
