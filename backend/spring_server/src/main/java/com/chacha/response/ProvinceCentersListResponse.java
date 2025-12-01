package com.chacha.response;

import com.chacha.dto.PagingDto;
import com.chacha.dto.BoundaryCenterDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.util.List;

@Schema(description = "광역시·도 경계 중심점 목록 응답")
@Data
public class ProvinceCentersListResponse {

    @Schema(description = "광역시·도 코드", example = "KR-INCHEON")
    private String provinceCode;

    @Schema(description = "총 경계 개수", example = "123")
    private int total;

    @Schema(description = "경계 중심점 리스트")
    private List<BoundaryCenterDto> centers;

    @Schema(description = "페이징 정보")
    private PagingDto paging;
}
