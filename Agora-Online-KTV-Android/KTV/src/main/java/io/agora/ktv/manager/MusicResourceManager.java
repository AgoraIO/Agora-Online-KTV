package io.agora.ktv.manager;

import android.content.Context;

import androidx.annotation.NonNull;

import com.agora.data.model.MusicModel;
import com.agora.data.provider.DataRepositroy;
import com.elvishew.xlog.Logger;
import com.elvishew.xlog.XLog;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.concurrent.Callable;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import io.agora.ktv.bean.MemberMusicModel;
import io.reactivex.Completable;
import io.reactivex.CompletableEmitter;
import io.reactivex.CompletableOnSubscribe;
import io.reactivex.Single;
import io.reactivex.SingleSource;
import io.reactivex.disposables.Disposable;
import io.reactivex.functions.Consumer;
import io.reactivex.functions.Function;

/**
 * Music Resource
 *
 * @author chenhengfei(Aslanchen)
 * @date 2021/06/01
 */
public final class MusicResourceManager {
    private Logger.Builder mLogger = XLog.tag("MusicRes");

    private Context mContext;
    private volatile static MusicResourceManager instance;

    private String resourceRoot;

    public static volatile boolean isPreparing = false;

    private MusicResourceManager(Context mContext) {
        this.mContext = mContext;
        resourceRoot = mContext.getExternalCacheDir().getPath();
    }

    public static MusicResourceManager Instance(Context mContext) {
        if (instance == null) {
            synchronized (MusicResourceManager.class) {
                if (instance == null)
                    instance = new MusicResourceManager(mContext.getApplicationContext());
            }
        }
        return instance;
    }

    public Single<MemberMusicModel> prepareMusic(final MemberMusicModel musicModel, boolean onlyLrc) {
        return DataRepositroy.Instance(mContext)
                .getMusic(musicModel.getMusicId())
                .firstOrError()
                .flatMap(new Function<MusicModel, SingleSource<MemberMusicModel>>() {
                    @Override
                    public SingleSource<MemberMusicModel> apply(@NonNull MusicModel model) throws Exception {
                        musicModel.setSong(model.getSong());
                        musicModel.setLrc(model.getLrc());

                        File fileMusic = new File(resourceRoot, musicModel.getMusicId());
                        File fileLrc;

                        if (model.getLrc().endsWith("zip")) {
                            fileLrc = new File(resourceRoot, musicModel.getMusicId() + ".zip");
                        } else if (model.getLrc().endsWith("xml")) {
                            fileLrc = new File(resourceRoot, musicModel.getMusicId() + ".xml");
                        } else if (model.getLrc().endsWith("lrc")) {
                            fileLrc = new File(resourceRoot, musicModel.getMusicId() + ".lrc");
                        } else {
                            return Single.error(new Throwable("未知歌词格式"));
                        }

                        musicModel.setFileMusic(fileMusic);
                        musicModel.setFileLrc(fileLrc);

                        mLogger.i("prepareMusic down %s", musicModel);
                        if (onlyLrc) {
                            Completable mCompletable = DataRepositroy.Instance(mContext).download(fileLrc, musicModel.getLrc());
                            if (model.getLrc().endsWith("zip")) {
                                mCompletable = mCompletable.andThen(Completable.create(new CompletableOnSubscribe() {
                                    @Override
                                    public void subscribe(@NonNull CompletableEmitter emitter) throws Exception {
                                        File fileLrcNew = new File(resourceRoot, musicModel.getMusicId() + ".xml");
                                        unzipLrc(fileLrc, fileLrcNew);
                                        musicModel.setFileLrc(fileLrcNew);
                                        emitter.onComplete();
                                    }
                                }));
                            }

                            return mCompletable.andThen(Single.just(musicModel));
                        } else {
                            Completable mCompletable = DataRepositroy.Instance(mContext).download(fileLrc, musicModel.getLrc());
                            if (model.getLrc().endsWith("zip")) {
                                mCompletable = mCompletable.andThen(Completable.create(new CompletableOnSubscribe() {
                                    @Override
                                    public void subscribe(@NonNull CompletableEmitter emitter) throws Exception {
                                        File fileLrcNew = new File(resourceRoot, musicModel.getMusicId() + ".xml");
                                        unzipLrc(fileLrc, fileLrcNew);
                                        musicModel.setFileLrc(fileLrcNew);
                                        emitter.onComplete();
                                    }
                                }));
                            }

                            return Completable.mergeArray(
                                    DataRepositroy.Instance(mContext).download(fileMusic, musicModel.getSong()),
                                    mCompletable)
                                    .toSingle(new Callable<MemberMusicModel>() {
                                        @Override
                                        public MemberMusicModel call() throws Exception {
                                            return musicModel;
                                        }
                                    });
                        }
                    }
                }).doOnSubscribe(new Consumer<Disposable>() {
                    @Override
                    public void accept(Disposable disposable) throws Exception {
                        isPreparing = true;
                    }
                }).doOnSuccess(new Consumer<MemberMusicModel>() {
                    @Override
                    public void accept(MemberMusicModel musicModel) throws Exception {
                        isPreparing = false;
                    }
                }).doOnError(new Consumer<Throwable>() {
                    @Override
                    public void accept(Throwable throwable) throws Exception {
                        isPreparing = false;
                        mLogger.e("prepareMusic error", throwable);
                    }
                });
    }

    private void unzipLrc(File src, File des) throws Exception {
        mLogger.i("prepareMusic unzipLrc %s", des);

        ZipInputStream inZip = new ZipInputStream(new FileInputStream(src));
        ZipEntry zipEntry;
        String szName = null;

        while ((zipEntry = inZip.getNextEntry()) != null) {
            szName = zipEntry.getName();
            if (zipEntry.isDirectory()) {
                continue;
            } else {
                des.createNewFile();
                FileOutputStream out = new FileOutputStream(des);
                int len;
                byte[] buffer = new byte[1024];
                while ((len = inZip.read(buffer)) != -1) {
                    out.write(buffer, 0, len);
                    out.flush();
                }
                out.close();
            }
        }
        inZip.close();
    }
}
