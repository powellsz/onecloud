package tasks

import (
	"context"

	"yunion.io/x/jsonutils"

	"yunion.io/x/onecloud/pkg/cloudcommon/db"
	"yunion.io/x/onecloud/pkg/cloudcommon/db/taskman"
	"yunion.io/x/onecloud/pkg/compute/models"
)

func init() {
	taskman.RegisterTask(GuestSoftResetTask{})
	taskman.RegisterTask(GuestHardResetTask{})
}

type GuestSoftResetTask struct {
	SGuestBaseTask
}

func (self *GuestSoftResetTask) OnInit(ctx context.Context, obj db.IStandaloneModel, data jsonutils.JSONObject) {
	guest := obj.(*models.SGuest)
	err := guest.GetDriver().RequestSoftReset(ctx, guest, self)
	if err == nil {
		self.SetStageComplete(ctx, nil)
	} else {
		self.SetStageFailed(ctx, err.Error())
	}
}

type GuestHardResetTask struct {
	SGuestBaseTask
}

func (self *GuestHardResetTask) OnInit(ctx context.Context, obj db.IStandaloneModel, data jsonutils.JSONObject) {
	guest := obj.(*models.SGuest)
	self.StopServer(ctx, guest)
}

func (self *GuestHardResetTask) StopServer(ctx context.Context, guest *models.SGuest) {
	guest.SetStatus(self.UserCred, models.VM_STOPPING, "")
	self.SetStage("OnServerStopComplete", nil)
	guest.StartGuestStopTask(ctx, self.UserCred, false, self.GetTaskId())
}

func (self *GuestHardResetTask) OnServerStopComplete(ctx context.Context, guest *models.SGuest, data jsonutils.JSONObject) {
	self.StartServer(ctx, guest)
}

func (self *GuestHardResetTask) StartServer(ctx context.Context, guest *models.SGuest) {
	self.SetStage("OnServerStartComplete", nil)
	guest.StartGueststartTask(ctx, self.UserCred, nil, self.GetTaskId())
}

func (self *GuestHardResetTask) OnServerStartComplete(ctx context.Context, guest *models.SGuest, data jsonutils.JSONObject) {
	self.SetStageComplete(ctx, nil)
}
