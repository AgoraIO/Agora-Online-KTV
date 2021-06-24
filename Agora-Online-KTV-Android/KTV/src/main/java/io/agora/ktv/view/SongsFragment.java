package io.agora.ktv.view;

import android.os.Bundle;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.agora.data.manager.UserManager;
import com.agora.data.model.AgoraRoom;
import com.agora.data.model.User;
import com.agora.data.provider.AgoraObject;
import com.agora.data.sync.AgoraException;
import com.agora.data.sync.SyncManager;

import java.util.ArrayList;
import java.util.List;

import io.agora.baselibrary.base.DataBindBaseFragment;
import io.agora.baselibrary.base.OnItemClickListener;
import io.agora.baselibrary.util.ToastUtile;
import io.agora.ktv.R;
import io.agora.ktv.adapter.SongsAdapter;
import io.agora.ktv.bean.MusicModel;
import io.agora.ktv.databinding.KtvFragmentSongListBinding;
import io.agora.ktv.manager.RoomManager;

/**
 * 歌单列表
 *
 * @author chenhengfei(Aslanchen)
 * @date 2021/6/15
 */
public class SongsFragment extends DataBindBaseFragment<KtvFragmentSongListBinding> implements OnItemClickListener<MusicModel> {

    public static SongsFragment newInstance() {
        SongsFragment mFragment = new SongsFragment();
        return mFragment;
    }

    private SongsAdapter mAdapter;

    @Override
    public void iniBundle(@NonNull Bundle bundle) {

    }

    @Override
    public int getLayoutId() {
        return R.layout.ktv_fragment_song_list;
    }

    @Override
    public void iniView(View view) {

    }

    @Override
    public void iniListener() {

    }

    @Override
    public void iniData() {
        mAdapter = new SongsAdapter(new ArrayList<>(), this);
        mDataBinding.list.setLayoutManager(new LinearLayoutManager(requireContext()));
        mDataBinding.list.setAdapter(mAdapter);

        mDataBinding.swipeRefreshLayout.setEnabled(false);

        mDataBinding.llEmpty.setVisibility(View.GONE);

        loadMusics();
    }

    private void loadMusics() {
        List<MusicModel> list = MusicModel.getMusicList();
        onLoadMusics(list);
    }

    private void onLoadMusics(List<MusicModel> list) {
        mAdapter.setDatas(list);
    }

    @Override
    public void onItemClick(@NonNull MusicModel data, View view, int position, long id) {
        AgoraRoom mRoom = RoomManager.Instance(requireContext()).getRoom();
        if (mRoom == null) {
            return;
        }

        User mUser = UserManager.Instance(requireContext()).getUserLiveData().getValue();
        if (mUser == null) {
            return;
        }

//        if (RoomManager.Instance(requireContext()).isInMusicOrderList(data)) {
//            mAdapter.notifyItemChanged(position);
//            return;
//        }

        data.setRoomId(mRoom);
        data.setUserId(mUser.getObjectId());
        SyncManager.Instance()
                .getRoom(mRoom.getId())
                .collection(MusicModel.TABLE_NAME)
                .add(data.toHashMap(), new SyncManager.DataItemCallback() {
                    @Override
                    public void onSuccess(AgoraObject result) {
                        MusicModel musicModel = result.toObject(MusicModel.class);
                        musicModel.setId(result.getId());
                        mAdapter.notifyItemChanged(position);
                    }

                    @Override
                    public void onFail(AgoraException exception) {
                        ToastUtile.toastShort(requireContext(), exception.getMessage());
                    }
                });
    }
}