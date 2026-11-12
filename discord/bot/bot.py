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

import cards
from store import Store

PREFIX = "CHILLAN1 "
TOKEN = os.environ["DISCORD_TOKEN"]
GUILD_ID = int(os.environ["GUILD_ID"])
RAW_ID = int(os.environ["RAW_CHANNEL_ID"])
FEED_ID = int(os.environ["FEED_CHANNEL_ID"])
DB_PATH = os.environ.get("DB_PATH", os.path.join(os.path.dirname(os.path.abspath(__file__)), "chillan.db"))
MAX_AGE = int(os.environ.get("MAX_EVENT_AGE_HOURS", "12")) * 3600  # older events are stored, not posted
STATUS_MIN_GAP = 30

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
        await update_status(e)
        return
    if not e.get("id"):
        return
    new = store.add(e)
    if not new:
        return
    fresh = e.get("k") == "TEST" or time.time() - int(e.get("t") or 0) <= MAX_AGE
    d = cards.card(e)
    if d and fresh:
        ch = await feed_channel()
        await ch.send(embed=embed(d))


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
    tree.copy_global_to(guild=guild_obj)
    await tree.sync(guild=guild_obj)
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


if __name__ == "__main__":
    client.run(TOKEN, log_handler=None)
