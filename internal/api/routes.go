package api

import (
	"github.com/gin-gonic/gin"
	"github.com/kanika1206/CodeEngine-GopherQueueSystem\/internal/queue"
)

func SetupRoutes(r *gin.Engine, q *queue.Queue) {
	handler := NewHandler(q)

	r.POST("/process", handler.ProcessContent)
	r.GET("/status", handler.CheckStatus)
}
