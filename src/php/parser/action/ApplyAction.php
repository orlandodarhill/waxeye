<?php


namespace parser\action;


use parser\continuation\Continuations;
use parser\result\MatchResult;

class ApplyAction extends Action
{
    private MatchResult $matchResult;

    public static function asApplyAction($action): ApplyAction
    {
        return $action;
    }

    /**
     * ApplyAction constructor.
     * @param Continuations $continuations
     * @param MatchResult $matchResult
     */
    public function __construct(Continuations $continuations, MatchResult $matchResult)
    {
        parent::__construct(ActionType::APPLY, $continuations);

        $this->matchResult = $matchResult;
    }

    public function jsonSerialize()
    {
        return get_object_vars($this);
    }

    public function __toString()
    {
        return json_encode($this);
    }

    /**
     * @return MatchResult
     */
    public function getMatchResult(): MatchResult
    {
        return $this->matchResult;
    }
}
