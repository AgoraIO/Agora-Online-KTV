package io.agora.ktv.bean;

import android.os.Parcel;
import android.os.Parcelable;

import androidx.annotation.Nullable;

import java.util.HashMap;

/**
 * @author chenhengfei(Aslanchen)
 * @date 2021/6/9
 */
public class MusicModel implements Parcelable {
    public static final String TABLE_NAME = "AgoraMusic";

    public static final String COLUMN_NAME = "name";
    public static final String COLUMN_USERID = "userId";
    public static final String COLUMN_ROOMID = "roomId";
    public static final String COLUMN_MUSICID = "musicId";
    public static final String COLUMN_CREATE = "createdAt";

    private String id;
    private String name;
    private String userId;
    private String roomId;
    private String musicId;

    protected MusicModel(Parcel in) {
        id = in.readString();
        name = in.readString();
        userId = in.readString();
        roomId = in.readString();
        musicId = in.readString();
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeString(id);
        dest.writeString(name);
        dest.writeString(userId);
        dest.writeString(roomId);
        dest.writeString(musicId);
    }

    @Override
    public int describeContents() {
        return 0;
    }

    public static final Creator<MusicModel> CREATOR = new Creator<MusicModel>() {
        @Override
        public MusicModel createFromParcel(Parcel in) {
            return new MusicModel(in);
        }

        @Override
        public MusicModel[] newArray(int size) {
            return new MusicModel[size];
        }
    };

    public HashMap<String, Object> toHashMap() {
        HashMap<String, Object> datas = new HashMap<>();
        datas.put(COLUMN_NAME, name);
        datas.put(COLUMN_USERID, userId);
        datas.put(COLUMN_ROOMID, roomId);
        datas.put(COLUMN_MUSICID, musicId);
        return datas;
    }

    public MusicModel(String musicId, String name) {
        this.musicId = musicId;
        this.name = name;
    }

    @Nullable
    public String getMusicFile() {
        if (musicId.equals("qinghuaci")) {
            return "qinghuaci.m4a";
        } else if (musicId.equals("send_it")) {
            return "send_it.m4a";
        } else {
            return null;
        }
    }

    @Nullable
    public String getMusicLrcFile() {
        if (musicId.equals("qinghuaci")) {
            return "qinghuaci.lrc";
        } else if (musicId.equals("send_it")) {
            return "send_it_cn.lrc";
        } else {
            return null;
        }
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getRoomId() {
        return roomId;
    }

    public void setRoomId(String roomId) {
        this.roomId = roomId;
    }

    public String getMusicId() {
        return musicId;
    }

    public void setMusicId(String musicId) {
        this.musicId = musicId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        MusicModel that = (MusicModel) o;

        if (id == null || id.isEmpty()) {
            return musicId.equals(that.musicId);
        }

        return id.equals(that.id);
    }

    @Override
    public int hashCode() {
        return id.hashCode();
    }
}