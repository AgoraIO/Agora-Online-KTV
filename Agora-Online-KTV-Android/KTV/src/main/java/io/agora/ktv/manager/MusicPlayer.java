package io.agora.ktv.manager;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;

import androidx.annotation.MainThread;
import androidx.annotation.NonNull;

import com.elvishew.xlog.Logger;
import com.elvishew.xlog.XLog;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import io.agora.ktv.bean.MemberMusicModel;
import io.agora.lrcview.LrcView;
import io.agora.mediaplayer.IMediaPlayer;
import io.agora.mediaplayer.IMediaPlayerObserver;
import io.agora.mediaplayer.data.MediaStreamInfo;
import io.agora.rtc2.ChannelMediaOptions;
import io.agora.rtc2.Constants;
import io.agora.rtc2.DataStreamConfig;
import io.agora.rtc2.IRtcEngineEventHandler;
import io.agora.rtc2.RtcEngine;
import io.reactivex.Completable;
import io.reactivex.CompletableEmitter;
import io.reactivex.SingleObserver;
import io.reactivex.disposables.Disposable;

public class MusicPlayer extends IRtcEngineEventHandler implements IMediaPlayerObserver {
    private Logger.Builder mLogger = XLog.tag("MusicPlayer");

    private Context mContext;
    private RtcEngine mRtcEngine;
    private LrcView mLrcView;
    private int mRole = Constants.CLIENT_ROLE_BROADCASTER;

    private boolean mStopSyncLrc = true;
    private Thread mSyncLrcThread;

    private boolean mStopDisplayLrc = true;
    private Thread mDisplayThread;

    private IMediaPlayer mPlayer;

    private static volatile long mRecvedPlayPosition = 0;
    private static volatile Long mLastRecvPlayPosTime = null;

    private static volatile int mAudioTracksCount = 0;
    private int[] mAudioTrackIndices = null;

    private static volatile MemberMusicModel mMusicModelOpen;
    private static volatile MemberMusicModel mMusicModel;

    private Callback mCallback;

    private static final int ACTION_UPDATE_TIME = 102;

    private static final int ACTION_ONMUSIC_OPENING = 200;
    private static final int ACTION_ON_MUSIC_OPENCOMPLETED = 201;
    private static final int ACTION_ON_MUSIC_OPENERROR = 202;
    private static final int ACTION_ON_MUSIC_PLAING = 203;
    private static final int ACTION_ON_MUSIC_PAUSE = 204;
    private static final int ACTION_ON_MUSIC_STOP = 205;
    private static final int ACTION_ON_MUSIC_COMPLETED = 206;
    private static final int ACTION_ON_MUSIC_PREPARING = 207;
    private static final int ACTION_ON_MUSIC_PREPARED = 208;
    private static final int ACTION_ON_MUSIC_PREPARE_FAIL = 209;

    private static volatile Status mStatus = Status.IDLE;

    enum Status {
        IDLE(0), Opened(1), Started(2), Paused(3), Stopped(4);

        int value;

        Status(int value) {
            this.value = value;
        }

        public boolean isAtLeast(@NonNull Status state) {
            return compareTo(state) >= 0;
        }
    }

    private final Handler mHandler = new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(@NonNull Message msg) {
            super.handleMessage(msg);
            if (msg.what == ACTION_UPDATE_TIME) {
                mLrcView.updateTime((long) msg.obj);
            } else if (msg.what == ACTION_ONMUSIC_OPENING) {
                if (mCallback != null) {
                    mCallback.onMusicOpening();
                }
            } else if (msg.what == ACTION_ON_MUSIC_OPENCOMPLETED) {
                if (mCallback != null) {
                    mCallback.onMusicOpenCompleted();
                }
            } else if (msg.what == ACTION_ON_MUSIC_OPENERROR) {
                if (mCallback != null) {
                    mCallback.onMusicOpenError((int) msg.obj);
                }
            } else if (msg.what == ACTION_ON_MUSIC_PLAING) {
                if (mCallback != null) {
                    mCallback.onMusicPlaing();
                }
            } else if (msg.what == ACTION_ON_MUSIC_PAUSE) {
                if (mCallback != null) {
                    mCallback.onMusicPause();
                }
            } else if (msg.what == ACTION_ON_MUSIC_STOP) {
                if (mCallback != null) {
                    mCallback.onMusicStop();
                }
            } else if (msg.what == ACTION_ON_MUSIC_COMPLETED) {
                if (mCallback != null) {
                    mCallback.onMusicCompleted();
                }
            } else if (msg.what == ACTION_ON_MUSIC_PREPARING) {
                if (mCallback != null) {
                    mCallback.onMusicPlaing();
                }
            } else if (msg.what == ACTION_ON_MUSIC_PREPARED) {
                if (mCallback != null) {
                    mCallback.onMusicPrepared();
                }
            } else if (msg.what == ACTION_ON_MUSIC_PREPARE_FAIL) {
                if (mCallback != null) {
                    mCallback.onMusicPrepareError();
                }
            }
        }
    };

    public MusicPlayer(Context mContext, RtcEngine mRtcEngine, LrcView lrcView) {
        this.mContext = mContext;
        this.mRtcEngine = mRtcEngine;
        this.mLrcView = lrcView;

        reset();

        // init mpk
        mPlayer = mRtcEngine.createMediaPlayer();
        mPlayer.registerPlayerObserver(this);

        mRtcEngine.addHandler(this);
    }

    private void reset() {
        mAudioTracksCount = 0;
        mAudioTrackIndices = null;
        mRecvedPlayPosition = 0;
        mLastRecvPlayPosTime = null;
        mMusicModelOpen = null;
        mMusicModel = null;
        mAudioTrackIndex = 1;
        mStatus = Status.IDLE;
    }

    public void registerPlayerObserver(Callback mCallback) {
        this.mCallback = mCallback;
    }

    public void unregisterPlayerObserver() {
        this.mCallback = null;
    }

    public void switchRole(int role) {
        mLogger.d("switchRole() called with: role = [%s]", role);
        mRole = role;

        ChannelMediaOptions options = new ChannelMediaOptions();

        options.publishMediaPlayerId = mPlayer.getMediaPlayerId();
        options.clientRoleType = role;
        options.autoSubscribeAudio = true;
        options.autoSubscribeVideo = false;
        options.publishCameraTrack = false;
        options.publishMediaPlayerVideoTrack = false;
        if (role == Constants.CLIENT_ROLE_BROADCASTER) {
            options.publishAudioTrack = true;
            options.publishCustomAudioTrack = false;
            options.enableAudioRecordingOrPlayout = true;
            options.publishMediaPlayerAudioTrack = true;
        } else {
            options.publishAudioTrack = false;
            options.publishCustomAudioTrack = false;
            options.enableAudioRecordingOrPlayout = false;
            options.publishMediaPlayerAudioTrack = false;
        }
        mRtcEngine.updateChannelMediaOptions(options);
    }

    public void playWithDisplay(MemberMusicModel mMusicModel) {
        MusicPlayer.mMusicModel = mMusicModel;
        startDisplayLrc();
    }

    public int play(MemberMusicModel mMusicModel) {
        if (mRole != Constants.CLIENT_ROLE_BROADCASTER) {
            mLogger.e("play: current role is not broadcaster, abort playing");
            return -1;
        }

        if (mStatus.isAtLeast(Status.Opened)) {
            mLogger.e("play: current player is in playing state already, abort playing");
            return -2;
        }

        if (!mStopDisplayLrc) {
            mLogger.e("play: current player is recving remote streams, abort playing");
            return -3;
        }

        File fileMusic = mMusicModel.getFileMusic();
        if (fileMusic.exists() == false) {
            mLogger.e("play: fileMusic is not exists");
            return -4;
        }

        File fileLrc = mMusicModel.getFileLrc();
        if (fileLrc.exists() == false) {
            mLogger.e("play: fileLrc is not exists");
            return -5;
        }

        ChannelMediaOptions options = new ChannelMediaOptions();
        options.publishMediaPlayerId = mPlayer.getMediaPlayerId();
        options.clientRoleType = mRole;
        options.autoSubscribeAudio = true;
        options.autoSubscribeVideo = false;
        options.publishCameraTrack = false;
        options.publishMediaPlayerVideoTrack = false;
        options.publishAudioTrack = true;
        options.publishCustomAudioTrack = false;
        options.enableAudioRecordingOrPlayout = true;
        options.publishMediaPlayerAudioTrack = true;
        mRtcEngine.updateChannelMediaOptions(options);

        stopDisplayLrc();
        // mpk open file
        mAudioTracksCount = 0;
        mAudioTrackIndex = 1;
        mAudioTrackIndices = null;
        MusicPlayer.mMusicModelOpen = mMusicModel;
        mLogger.i("play() called with: mMusicModel = [%s]", mMusicModel);
        mPlayer.open(fileMusic.getAbsolutePath(), 0);
        return 0;
    }

    private volatile CompletableEmitter emitterStop;

    public Completable stop() {
        mLogger.i("stop() called");
        if (mStatus == Status.IDLE) {
            return Completable.complete();
        }

        return Completable.create(emitter -> {
            this.emitterStop = emitter;

            ChannelMediaOptions options = new ChannelMediaOptions();
            options.publishMediaPlayerId = mPlayer.getMediaPlayerId();
            options.clientRoleType = mRole;
            options.autoSubscribeAudio = true;
            options.autoSubscribeVideo = false;
            options.publishCameraTrack = false;
            options.publishMediaPlayerVideoTrack = false;
            options.publishAudioTrack = false;
            options.publishCustomAudioTrack = false;
            options.enableAudioRecordingOrPlayout = false;
            options.publishMediaPlayerAudioTrack = false;
            mRtcEngine.updateChannelMediaOptions(options);
            // mpk stop
            mPlayer.stop();
        });
    }

    private void pause() {
        mLogger.i("pause() called");
        if (mStatus == Status.Paused)
            return;

        mPlayer.pause();
    }

    private void resume() {
        mLogger.i("resume() called");
        if (mStatus == Status.Started)
            return;

        mPlayer.resume();
    }

    public void toggleStart() {
        if (!mStatus.isAtLeast(Status.Started)) {
            return;
        }

        if (mStatus == Status.Started) {
            pause();
        } else if (mStatus == Status.Paused) {
            resume();
        }
    }

    private int mAudioTrackIndex = 1;

    public void selectAudioTrack(int i) {
        //        if (i < 0 || mAudioTracksCount == 0 || i >= mAudioTracksCount)
//            return;
//
//        mAudioTrackIndex = i;
//
//        if (mMusicModel.getType() == MemberMusicModel.Type.Default) {
//            mPlayer.selectAudioTrack(mAudioTrackIndices[i]);
//        } else {
//            mPlayer.setAudioDualMonoMode(mAudioTracksCount);
//        }

        //因为咪咕音乐没有音轨，只有左右声道，所以暂定如此
        mAudioTrackIndex = i;

        if (mAudioTrackIndex == 0) {
            mPlayer.setAudioDualMonoMode(1);
        } else {
            mPlayer.setAudioDualMonoMode(2);
        }
    }

    public boolean hasAccompaniment() {
//        return mAudioTracksCount >= 2;

        //因为咪咕音乐没有音轨，只有左右声道，所以暂定如此
        return true;
    }

    public void toggleOrigle() {
        if (mAudioTrackIndex == 0) {
            selectAudioTrack(1);
        } else {
            selectAudioTrack(0);
        }
    }

    public void setMusicVolume(int v) {
        mPlayer.adjustPlayoutVolume(v);
    }

    public void setMicVolume(int v) {
        mRtcEngine.adjustRecordingSignalVolume(v);
    }

    public void seek(long d) {
        mPlayer.seek(d);
    }

    private void startDisplayLrc() {
        File lrcs = mMusicModel.getFileLrc();
        mLrcView.post(new Runnable() {
            @Override
            public void run() {
                mLrcView.loadLrc(lrcs);
            }
        });

        mStopDisplayLrc = false;
        mDisplayThread = new Thread(new Runnable() {
            @Override
            public void run() {
                long curTs = 0;
                long curTime;
                long offset;
                while (!mStopDisplayLrc) {
                    if (mLastRecvPlayPosTime != null) {
                        curTime = System.currentTimeMillis();

                        offset = curTime - mLastRecvPlayPosTime;

                        if (offset <= 1000) {
                            curTs = mRecvedPlayPosition + offset;
                            mHandler.obtainMessage(ACTION_UPDATE_TIME, curTs).sendToTarget();
                        }
                    }

                    try {
                        Thread.sleep(50);
                    } catch (InterruptedException exp) {
                        break;
                    }
                }
            }
        });
        mDisplayThread.start();
    }

    private void stopDisplayLrc() {
        mStopDisplayLrc = true;
        if (mDisplayThread != null) {
            try {
                mDisplayThread.join();
            } catch (InterruptedException exp) {
                mLogger.e("stopDisplayLrc: " + exp.getMessage());
            }
        }
        mLrcView.post(new Runnable() {
            @Override
            public void run() {
                mLrcView.reset();
            }
        });
        mMusicModel = null;
    }

    private void startSyncLrc(String lrcId, long duration) {
        mSyncLrcThread = new Thread(new Runnable() {
            int mStreamId = -1;

            @Override
            public void run() {
                mLogger.i("startSyncLrc: " + lrcId);
                DataStreamConfig cfg = new DataStreamConfig();
                cfg.syncWithAudio = true;
                cfg.ordered = true;
                mStreamId = mRtcEngine.createDataStream(cfg);

                mStopSyncLrc = false;
                while (!mStopSyncLrc && mStatus.isAtLeast(Status.Started)) {
                    if (mPlayer == null) {
                        break;
                    }

                    if (mLastRecvPlayPosTime != null && mStatus == Status.Started) {
                        sendSyncLrc(lrcId, duration, mRecvedPlayPosition);
                    }

                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException exp) {
                        break;
                    }
                }

                sendMusicStop(lrcId);
                mLogger.i("stoppedSyncLrc: " + lrcId);
            }

            private void sendSyncLrc(String lrcId, long duration, long time) {
                Map<String, Object> msg = new HashMap<>();
                msg.put("cmd", "setLrcTime");
                msg.put("lrcId", lrcId);
                msg.put("duration", duration);
                msg.put("time", time);//ms
                JSONObject jsonMsg = new JSONObject(msg);
                mRtcEngine.sendStreamMessage(mStreamId, jsonMsg.toString().getBytes());
            }

            private void sendMusicStop(String lrcId) {
                Map<String, Object> msg = new HashMap<>();
                msg.put("cmd", "musicStopped");
                msg.put("lrcId", lrcId);
                JSONObject jsonMsg = new JSONObject(msg);
                mRtcEngine.sendStreamMessage(mStreamId, jsonMsg.toString().getBytes());
            }
        });
        mSyncLrcThread.start();
    }

    private void stopSyncLrc() {
        mStopSyncLrc = true;
        if (mSyncLrcThread != null) {
            try {
                mSyncLrcThread.join();
            } catch (InterruptedException exp) {
                mLogger.e("stopSyncLrc: " + exp.getMessage());
            }
        }
    }

    private void startPublish() {
        startSyncLrc(mMusicModel.getMusicId(), mPlayer.getDuration());
    }

    private void stopPublish() {
        stopSyncLrc();
    }

    private void initAudioTracks() {
        if (mMusicModel.getType() != MemberMusicModel.Type.Default) {
            return;
        }

        int nt = mPlayer.getStreamCount();
        int nat = 0;
        mAudioTrackIndices = new int[nt];
        for (int i = 0; i < nt; ++i) {
            MediaStreamInfo stmInfo = mPlayer.getStreamInfo(i);
            if (stmInfo != null && stmInfo.getMediaStreamType() ==
                    io.agora.mediaplayer.Constants.MediaStreamType.getValue(
                            io.agora.mediaplayer.Constants.MediaStreamType.STREAM_TYPE_AUDIO)) {
                mAudioTrackIndices[nat] = stmInfo.getStreamIndex();
                ++nat;
            }
        }
        mAudioTracksCount = nat;
    }

    @Override
    public void onStreamMessage(int uid, int streamId, byte[] data) {
        JSONObject jsonMsg;
        try {
            String strMsg = new String(data);
            jsonMsg = new JSONObject(strMsg);
            mLogger.i("onStreamMessage: recv msg: " + strMsg);

            if (jsonMsg.getString("cmd").equals("setLrcTime")) {
                if (mMusicModel == null || !jsonMsg.getString("lrcId").equals(mMusicModel.getMusicId())) {
                    if (MusicResourceManager.isPreparing) {
                        return;
                    }

                    stopDisplayLrc();

                    // 加载歌词文本
                    String musicId = jsonMsg.getString("lrcId");
                    long duration = jsonMsg.getLong("duration");

                    onMusicPreparing();
                    MemberMusicModel musicModel = new MemberMusicModel(musicId);
                    MusicResourceManager.Instance(mContext)
                            .prepareMusic(musicModel, true)
                            .subscribe(new SingleObserver<MemberMusicModel>() {
                                @Override
                                public void onSubscribe(@NonNull Disposable d) {

                                }

                                @Override
                                public void onSuccess(@NonNull MemberMusicModel musicModel) {
                                    onMusicPrepared();
                                    playWithDisplay(musicModel);
                                }

                                @Override
                                public void onError(@NonNull Throwable e) {
                                    onMusicPrepareError();
                                }
                            });
                }
                mRecvedPlayPosition = jsonMsg.getLong("time");
                mLastRecvPlayPosTime = System.currentTimeMillis();
            } else if (jsonMsg.getString("cmd").equals("musicStopped")) {
                stopDisplayLrc();
            }
        } catch (JSONException exp) {
            mLogger.e("onStreamMessage: failed parse json, error: " + exp.toString());
        }
    }

    @Override
    public void onPlayerStateChanged(io.agora.mediaplayer.Constants.MediaPlayerState state, io.agora.mediaplayer.Constants.MediaPlayerError error) {
        mLogger.i("onPlayerStateChanged: " + state + ", error: " + error);
        switch (state) {
            case PLAYER_STATE_OPENING:
                onMusicOpening();
                break;
            case PLAYER_STATE_OPEN_COMPLETED:
                onMusicOpenCompleted();
                break;
            case PLAYER_STATE_PLAYING:
                onMusicPlaing();
                break;
            case PLAYER_STATE_PAUSED:
                onMusicPause();
                break;
            case PLAYER_STATE_STOPPED:
                onMusicStop();
                break;
            case PLAYER_STATE_FAILED:
                onMusicOpenError(io.agora.mediaplayer.Constants.MediaPlayerError.getValue(error));
                mLogger.e("onPlayerStateChanged: failed to play, error " + error);
                break;
            default:
        }
    }

    @Override
    public void onPositionChanged(long position) {
        mLogger.d("onPositionChanged() called with: position = [%s]", position);
        mRecvedPlayPosition = position;
        mLastRecvPlayPosTime = System.currentTimeMillis();
    }

    @Override
    public void onPlayerEvent(io.agora.mediaplayer.Constants.MediaPlayerEvent eventCode) {

    }

    @Override
    public void onMetaData(io.agora.mediaplayer.Constants.MediaPlayerMetadataType type, byte[] data) {

    }

    @Override
    public void onPlayBufferUpdated(long l) {

    }

    @Override
    public void onCompleted() {
        onMusicCompleted();
    }

    private void onMusicOpening() {
        mLogger.i("onMusicOpening() called");
        mHandler.obtainMessage(ACTION_ONMUSIC_OPENING).sendToTarget();
    }

    private void onMusicOpenCompleted() {
        mLogger.i("onMusicOpenCompleted() called");
        mStatus = Status.Opened;

        MusicPlayer.mMusicModel = mMusicModelOpen;
        mMusicModelOpen = null;

        initAudioTracks();

        mLrcView.setTotalDuration(mPlayer.getDuration());
        mPlayer.play();
        startDisplayLrc();
        mHandler.obtainMessage(ACTION_ON_MUSIC_OPENCOMPLETED).sendToTarget();
    }

    private void onMusicOpenError(int error) {
        mLogger.i("onMusicOpenError() called with: error = [%s]", error);
        reset();

        mHandler.obtainMessage(ACTION_ON_MUSIC_OPENERROR, error).sendToTarget();
    }

    private void onMusicPlaing() {
        mLogger.i("onMusicPlaing() called");
        mStatus = Status.Started;

        if (mStopSyncLrc)
            startPublish();

        mHandler.obtainMessage(ACTION_ON_MUSIC_PLAING).sendToTarget();
    }

    private void onMusicPause() {
        mLogger.i("onMusicPause() called");
        mStatus = Status.Paused;

        mHandler.obtainMessage(ACTION_ON_MUSIC_PAUSE).sendToTarget();
    }

    private void onMusicStop() {
        mLogger.i("onMusicStop() called");
        mStatus = Status.Stopped;

        stopDisplayLrc();
        stopPublish();
        reset();

        if (emitterStop != null) {
            emitterStop.onComplete();
        }

        mHandler.obtainMessage(ACTION_ON_MUSIC_STOP).sendToTarget();
    }

    private void onMusicCompleted() {
        mLogger.i("onMusicCompleted() called");
        mPlayer.stop();
        stopDisplayLrc();
        stopPublish();
        reset();

        mHandler.obtainMessage(ACTION_ON_MUSIC_COMPLETED).sendToTarget();
    }

    private void onMusicPreparing() {
        mLogger.i("onMusicPreparing() called");
        mHandler.obtainMessage(ACTION_ON_MUSIC_PREPARING).sendToTarget();
    }

    private void onMusicPrepared() {
        mLogger.i("onMusicPrepared() called");
        mHandler.obtainMessage(ACTION_ON_MUSIC_PREPARED).sendToTarget();
    }

    private void onMusicPrepareError() {
        mLogger.i("onMusicPrepareError() called");
        mHandler.obtainMessage(ACTION_ON_MUSIC_PREPARE_FAIL).sendToTarget();
    }

    public void destory() {
        mLogger.i("destory() called");
        mRtcEngine.removeHandler(this);
        mCallback = null;

        mPlayer.destroy();
        mPlayer = null;
    }

    @MainThread
    public interface Callback {
        void onMusicOpening();

        void onMusicOpenCompleted();

        void onMusicOpenError(int error);

        void onMusicPlaing();

        void onMusicPause();

        void onMusicStop();

        void onMusicCompleted();

        void onMusicPreparing();

        void onMusicPrepared();

        void onMusicPrepareError();
    }
}
