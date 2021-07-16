#!/usr/bin/python3

import leancloud
import json
import requests
import base64
from leancloud import cloud

appid = ''
appkey = ''

# 客户 ID
customer_key = "Your customer key"
# 客户密钥
customer_secret = "Your customer secret"
agora_app_id = '80e54398fed94ae8a010acf782f569b7'

# 拼接客户 ID 和客户密钥
credentials = customer_key + ":" + customer_secret
# 使用 base64 进行编码
base64_credentials = base64.b64encode(credentials.encode("utf8"))
credential = base64_credentials.decode("utf8")

headers = {'Content-Type': 'application/json',
           'Authorization': 'Basic MjdiZjhjMmRkNTNhNGQwZGEwMWQxNmM4MTllOWE5Yzc6YjM2N2NiMjRiOTExNDQyYTg5YjU5YTdmN2Y0YjM1OWM='}

isInit = False

total = 0


def insertMusicRecursive(songCode):
    global total
    size = 1000
    url = "https://api.agora.io/cn/v1.0/projects/{}/ktv-service/api/serv/songs?requestId=1&pageCode={}&size={}".format(
        agora_app_id, songCode, size)
    r = requests.get(url, headers=headers)
    res = json.loads(r.text)
    count = res["data"]["count"]
    total += count
    if count > 0:
        MusicRepo = leancloud.Object.extend('MUSIC_REPOSITORY')
        last_song_code = res["data"]["list"][res["data"]["count"] - 1]["songCode"]
        for song in res["data"]["list"]:
            # print(song["songCode"], song["name"])
            musicRepo = MusicRepo()
            musicRepo.set('musicId', str(song["songCode"]))
            musicRepo.set('name', song["name"])
            musicRepo.save()
        insertMusicRecursive(last_song_code)
    else:
        print("fetch finished! total:", total)


def getMusic(songCode):
    r = requests.get(
        "https://api.agora.io/cn/v1.0/projects/{}/ktv-service/api/serv/song-url?requestId=1&songCode={}&lyricType=0".format(agora_app_id, songCode),
        headers=headers)
    print(r.text)
https://api.agora.io/cn/v1.0/projects/{}/ktv-service/api/serv/song-url?requestId=1&songCode=6246262727339400
https://api.agora.io/cn/v1.0/projects/{}/ktv-service/api/serv/song-url?requestId=1&songCode={}&lyricType=0

def init():
    global isInit
    isInit = False
    if appid == None or len(appid) <= 0:
        print("appid is empty")
        return

    if appkey == None or len(appkey) <= 0:
        print("appkey is empty")
        return

    leancloud.init(appid, appkey)
    isInit = True


def getList():
    MusicRepo = leancloud.Object.extend('MUSIC_REPOSITORY')
    query = MusicRepo.query
    list = query.find()
    for music in list:
        print(music.get('musicId'), music.get('name'))


def runFun():
    print("lrc url:", cloud.run('getMusic', id='001'))


def reset_music_table():
    if (isInit == False):
        return
    insertMusicRecursive(0)

    print("数据库创建成功。")


# init()
# runFun()
reset_music_table()
# getMusic(6246262727339371)
