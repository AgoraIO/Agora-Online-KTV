package io.agora.scene.ktv;

import cn.leancloud.EngineFunction;
import cn.leancloud.EngineFunctionParam;
import cn.leancloud.sms.AVSMS;
import cn.leancloud.sms.AVSMSOption;
import cn.leancloud.types.AVNull;
import cn.leancloud.utils.StringUtil;
import io.reactivex.Observer;
import io.reactivex.disposables.Disposable;
import org.springframework.beans.factory.annotation.Autowired;

import java.io.IOException;

public class Cloud {

  private static OnLineResourceService resourceService = new OnLineResourceService();

  @EngineFunction("getMusic")
  public static String getMusic(@EngineFunctionParam("id") String id) throws IOException {
    if (id == null) {
      return "400 Bad Request";
    }
    return resourceService.getMusicUrl(id);
  }

}
