package com.chacha.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

import java.util.List;

import com.chacha.dto.BoundaryCenterDto;

@Schema(description = "구 내 동 경계 중심점 리스트 응답")
@Getter
@Setter
public class DistrictCentersListResponse {

    @Schema(description = "구 코드", example = "KR-SEOUL-SEOCHOGU")
    private String districtCode;

    @Schema(description = "총 건수", example = "123")
    private int total;

    @Schema(description = "센터 목록")
    private List<BoundaryCenterDto> centers;
}
