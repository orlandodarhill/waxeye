<?php


namespace ast;


use util\ArrayIteratorStr;

class IASTs extends ArrayIteratorStr
{
    public function __construct(IAST...$iasts)
    {
        parent::__construct($iasts);
    }

    public function current(): IAST
    {
        return parent::current();
    }

    public function offsetGet($index): IAST
    {
        return parent::offsetGet($index);
    }
}