package io.agora.lrcview.bean;

import java.util.List;

import io.agora.lrcview.LrcEntry;

/**
 * 歌词数据-咪咕歌词
 *
 * @author chenhengfei(Aslanchen)
 * @date 2021/7/6
 */
public class LrcEntryMigu implements IEntry {
    @Override
    public Type getType() {
        return Type.Migu;
    }

    @Override
    public void setDuration(long d) {

    }

    @Override
    public long getStartTime() {
        Tone first = tones.get(0);
        return (long) (first.begin * 1000L);
    }

    private IEntry.Tone[] LocalTones;

    @Override
    public IEntry.Tone[] getTones() {
        return LocalTones;
    }

    @Override
    public LrcEntry createLRCEntry() {
        LocalTones = new IEntry.Tone[tones.size()];
        for (int i = 0; i < tones.size(); i++) {
            Tone tone = tones.get(i);

            IEntry.Tone localTone = new IEntry.Tone();
            localTone.begin = (long) (tone.begin * 1000);
            localTone.end = (long) (tone.end * 1000);
            localTone.word = tone.word;

            if ("1".equals(tone.lang)) {
                localTone.lang = Lang.Chinese;
            } else {
                localTone.lang = Lang.English;
            }

            LocalTones[i] = localTone;
        }
        return new LrcEntry(this);
    }

    public enum Mode {
        Default, Woman, Man
    }

    public Mode mode;
    public List<Tone> tones;

    public static class Tone {
        public float begin;
        public float end;
        public int pitch;
        public String pronounce;
        public String lang = "1";
        public String word;
    }
}
